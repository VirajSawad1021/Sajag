// Collect evidence for a new case, or add the seller's reply to an existing one.
import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../l10n.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'analyzing_screen.dart';
import 'redact_screen.dart';

// Synthetic wallet + bank SMS for the sample (no real numbers).
const _sampleSms = 'You have sent Rs. 3200 to 98XXXXX321 (Sushil Rai). Txn ID: TXN-7Q4K-2291 on 2026-09-28 19:28\n\n'
    'Dear Customer, your A/C XXXX1234 has been debited by NPR 3,200.00 on 28-09-2026 for eSewa load. Ref No: FT2609281928';

/// What kind of check: a purchase (default) or a friend/relative asking for money (possible hacked account).
enum CheckMode { purchase, friend }

class NewCheckScreen extends StatefulWidget {
  const NewCheckScreen({super.key, this.caseId, this.initial = const [], this.mode = CheckMode.purchase});
  final CheckMode mode;
  final String? caseId; // set when adding the seller's reply to an existing case
  final List<Evidence> initial; // evidence shared into Sajag from another app

  @override
  State<NewCheckScreen> createState() => _NewCheckScreenState();
}

class _NewCheckScreenState extends State<NewCheckScreen> {
  final List<Evidence> _added = [];
  final _text = TextEditingController();
  final _recorder = AudioRecorder();
  String _stage = 'before_payment';
  bool _recording = false;
  int _recordSeconds = 0;
  Timer? _timer;

  SajagCase? get _existing => widget.caseId == null ? null : store.byId(widget.caseId!);

  @override
  void initState() {
    super.initState();
    _stage = _existing?.stage ?? 'before_payment';
    _added.addAll(widget.initial.where((e) => e.kind != EvidenceKind.text));
    _text.text = widget.initial.where((e) => e.kind == EvidenceKind.text).map((e) => e.text).join('\n\n');
  }

  @override
  void dispose() {
    _timer?.cancel();
    _recorder.dispose();
    _text.dispose();
    super.dispose();
  }

  Future<void> _pickImages({bool camera = false}) async {
    final picker = ImagePicker();
    final files = camera
        ? [?await picker.pickImage(source: ImageSource.camera, imageQuality: 85)]
        : await picker.pickMultiImage(imageQuality: 90, limit: 6);
    for (final f in files) {
      final bytes = await f.readAsBytes();
      final mime = f.mimeType ?? (f.name.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg');
      setState(() => _added.add(Evidence(kind: EvidenceKind.image, name: f.name, mime: mime, bytes: bytes)));
    }
  }

  Future<void> _pickAudio() async {
    final files = await FilePicker.pickFiles(type: FileType.audio);
    for (final f in files) {
      final bytes = await f.readAsBytes();
      final ext = (f.extension ?? '').toLowerCase();
      final mime = switch (ext) { 'm4a' || 'mp4' || 'aac' => 'audio/mp4', 'mp3' => 'audio/mpeg', 'wav' => 'audio/wav', _ => 'audio/ogg' };
      setState(() => _added.add(Evidence(kind: EvidenceKind.audio, name: f.name, mime: mime, bytes: bytes)));
    }
  }

  Future<void> _toggleRecording() async {
    if (_recording) {
      _timer?.cancel();
      final path = await _recorder.stop();
      setState(() => _recording = false);
      if (path == null) return;
      final bytes = await XFile(path).readAsBytes(); // a file path on Android, a blob URL on the web
      final web = kIsWeb;
      setState(() => _added.add(Evidence(
            kind: EvidenceKind.audio,
            name: 'voice-${DateTime.now().millisecondsSinceEpoch}.${web ? 'webm' : 'm4a'}',
            mime: web ? 'audio/webm' : 'audio/mp4',
            bytes: bytes,
          )));
      return;
    }
    if (!await _recorder.hasPermission()) {
      if (mounted) toast(context, lang.ne ? 'माइक्रोफोन अनुमति चाहिन्छ।' : 'Microphone permission is needed.');
      return;
    }
    final path = kIsWeb ? '' : '${(await getTemporaryDirectory()).path}/sajag-${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(RecordConfig(encoder: kIsWeb ? AudioEncoder.opus : AudioEncoder.aacLc), path: path);
    setState(() {
      _recording = true;
      _recordSeconds = 0;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() => _recordSeconds++);
      if (_recordSeconds >= 120) _toggleRecording();
    });
  }

  /// Hide private details in an image before it is sent (OTP, balance, account number, faces).
  Future<void> _hide(int i) async {
    final e = _added[i];
    final hidden = await RedactScreen.open(context, e.bytes!);
    if (hidden == null || !mounted) return;
    final name = e.name.replaceFirst(RegExp(r'\.\w+$'), '');
    setState(() => _added[i] = Evidence(kind: EvidenceKind.image, name: '$name-hidden.png', mime: 'image/png', bytes: hidden));
  }

  Future<void> _loadSample(String file, EvidenceKind kind, {String? stage, bool add = false}) async {
    final data = await rootBundle.load('assets/demo/$file');
    final mime = kind == EvidenceKind.audio ? 'audio/ogg' : 'image/png';
    setState(() {
      if (_existing == null && !add) _added.clear();
      _added.add(Evidence(kind: kind, name: file, mime: mime, bytes: data.buffer.asUint8List()));
      if (stage != null) _stage = stage;
    });
  }

  Future<void> _submit() async {
    final text = _text.text.trim();
    if (_added.isEmpty && text.isEmpty) {
      toast(context, tr('needEvidence'));
      return;
    }
    final c = _existing ?? SajagCase(stage: _stage);
    c.stage = _stage;
    c.evidence.addAll(_added);
    if (text.isNotEmpty) c.evidence.add(Evidence(kind: EvidenceKind.text, name: 'message.txt', text: text));
    if (_stage == 'after_payment' && c.status == CaseStatus.watching) c.status = CaseStatus.paid;
    await store.save(c);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => AnalyzingScreen(caseId: c.id)));
  }

  @override
  Widget build(BuildContext context) {
    final reply = _existing != null;
    return Scaffold(
      appBar: AppBar(title: Text(reply ? tr('addReply') : tr('newCheck'))),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 120), children: [
        if (widget.mode == CheckMode.friend)
          Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Module(
              color: C.infoBg,
              borderColor: C.infoBg,
              child: Text(tr('friendHint'), style: T.small.copyWith(color: C.info)),
            ),
          ),
        if (reply)
          Module(
            color: C.infoBg,
            borderColor: C.infoBg,
            child: Text(
              lang.ne
                  ? 'बिक्रेताको जवाफको स्क्रिनसट वा भ्वाइस नोट थप्नुहोस्। अघिल्लो प्रमाणसँगै फेरि जाँचिन्छ।'
                  : 'Add a screenshot or voice note of the seller\'s reply. It is checked again together with the earlier evidence.',
              style: T.small.copyWith(color: C.info),
            ),
          )
        else ...[
          Text(tr('stageQ'), style: T.label),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: [
              ButtonSegment(value: 'before_payment', label: Text(tr('notYet'))),
              ButtonSegment(value: 'after_payment', label: Text(tr('paid'))),
            ],
            selected: {_stage},
            showSelectedIcon: false,
            style: SegmentedButton.styleFrom(
              selectedBackgroundColor: C.ink,
              selectedForegroundColor: Colors.white,
              side: const BorderSide(color: C.border),
            ),
            onSelectionChanged: (v) => setState(() => _stage = v.first),
          ),
        ],
        const SizedBox(height: 22),
        Text(tr('addEvidence'), style: T.label),
        const SizedBox(height: 8),
        Module(
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 2.3,
              children: [
                _SourceButton(icon: Icons.photo_library_outlined, label: tr('screenshot'), onTap: () => _pickImages()),
                _SourceButton(icon: Icons.photo_camera_outlined, label: tr('camera'), onTap: () => _pickImages(camera: true)),
                _SourceButton(icon: Icons.audio_file_outlined, label: tr('voiceFile'), onTap: _pickAudio),
                _SourceButton(
                  icon: _recording ? Icons.stop_circle_outlined : Icons.mic_none_rounded,
                  label: _recording ? '${tr('stop')} · ${_recordSeconds}s' : tr('record'),
                  onTap: _toggleRecording,
                  active: _recording,
                ),
              ],
            ),
            if (_added.isNotEmpty) ...[
              const SizedBox(height: 12),
              SizedBox(
                height: 92,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _added.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, i) => _EvidenceThumb(
                    e: _added[i],
                    onRemove: () => setState(() => _added.removeAt(i)),
                    onHide: _added[i].kind == EvidenceKind.image ? () => _hide(i) : null,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _text,
              minLines: 3,
              maxLines: 8,
              decoration: InputDecoration(hintText: tr('pasteHint')),
            ),
          ]),
        ),
        const SizedBox(height: 16),
        Text(tr('samples'), style: T.label),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: reply
            ? [_SampleChip(lang.ne ? '↩ बिक्रेताको जवाफ' : '↩ Seller\'s reply', () => _loadSample('seller-reply.png', EvidenceKind.image))]
            : widget.mode == CheckMode.friend
                ? [_SampleChip(tr('friendSample'), () => _loadSample('friend-request.png', EvidenceKind.image))]
                : [
                _SampleChip('COD → advance + QR', () => _loadSample('scam-chat.png', EvidenceKind.image)),
                _SampleChip(lang.ne ? 'इमानदार बिक्रेता' : 'Honest seller', () => _loadSample('honest-chat.png', EvidenceKind.image)),
                _SampleChip(lang.ne ? 'बैंक SMS' : 'Bank SMS', () => setState(() {
                  _stage = 'after_payment';
                  _text.text = _sampleSms;
                })),
                _SampleChip(lang.ne ? '🎙 पैसा तिरें, सामान आएन' : '🎙 Paid, nothing came', () async {
                  await _loadSample('voice-victim.ogg', EvidenceKind.audio, stage: 'after_payment');
                  await _loadSample('receipt.png', EvidenceKind.image, add: true);
                }),
              ]),
        const SizedBox(height: 18),
        Text(tr('privacyNote'), style: T.meta),
      ]),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Pill(tr('check'), big: true, icon: Icons.shield_outlined, onTap: _recording ? null : _submit),
        ),
      ),
    );
  }
}

class _SourceButton extends StatelessWidget {
  const _SourceButton({required this.icon, required this.label, required this.onTap, this.active = false});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) => RaisedCard(
        onTap: onTap,
        accent: active ? C.high : null,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(children: [
          Icon(icon, color: active ? C.high : C.ink, size: 22),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: T.small.copyWith(color: active ? C.high : C.ink, fontWeight: FontWeight.w600))),
        ]),
      );
}

class _EvidenceThumb extends StatelessWidget {
  const _EvidenceThumb({required this.e, required this.onRemove, this.onHide});
  final Evidence e;
  final VoidCallback onRemove;
  final VoidCallback? onHide; // images only: open the hide-details editor

  @override
  Widget build(BuildContext context) => Stack(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(R.field),
          child: Container(
            width: 72,
            height: 92,
            color: C.raised,
            child: e.kind == EvidenceKind.image
                ? Image.memory(e.bytes!, fit: BoxFit.cover, alignment: Alignment.topCenter)
                : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Icon(Icons.graphic_eq_rounded, color: C.ink),
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(e.name, style: T.meta.copyWith(fontSize: 10), maxLines: 2, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
                    ),
                  ]),
          ),
        ),
        if (onHide != null)
          Positioned(
            left: 2,
            bottom: 2,
            child: Semantics(
              button: true,
              label: tr('hideDetails'),
              child: InkWell(
                onTap: onHide,
                child: Container(
                  decoration: const BoxDecoration(color: Colors.black87, shape: BoxShape.circle),
                  padding: const EdgeInsets.all(5),
                  child: const Icon(Icons.visibility_off_outlined, size: 15, color: Colors.white),
                ),
              ),
            ),
          ),
        Positioned(
          right: 2,
          top: 2,
          child: InkWell(
            onTap: onRemove,
            child: Container(
              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
              padding: const EdgeInsets.all(3),
              child: const Icon(Icons.close_rounded, size: 14, color: Colors.white),
            ),
          ),
        ),
      ]);
}

class _SampleChip extends StatelessWidget {
  const _SampleChip(this.label, this.onTap);
  final String label;
  final VoidCallback onTap;

  // A plain pill button (ActionChip is announced as a checkbox on the web, which misleads screen readers).
  @override
  Widget build(BuildContext context) => Pill(label, primary: false, onTap: onTap);
}
