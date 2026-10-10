// Live analysis: the user's screenshot is scanned while Gemma's progress streams in step by step.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api.dart';
import '../demo.dart';
import '../l10n.dart';
import '../models.dart';
import '../notifications.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/xray.dart';
import 'case_screen.dart';

class AnalyzingScreen extends StatefulWidget {
  const AnalyzingScreen({super.key, required this.caseId});
  final String caseId;

  @override
  State<AnalyzingScreen> createState() => _AnalyzingScreenState();
}

class _FeedItem {
  _FeedItem(this.icon, this.text, {this.detail, this.color = C.ink});
  final IconData icon;
  final String text;
  final String? detail;
  final Color color;
}

class _AnalyzingScreenState extends State<AnalyzingScreen> {
  final List<_FeedItem> _feed = [];
  final Set<String> _phasesSeen = {};
  String? _error;
  int _chars = 0;
  final _stopwatch = Stopwatch();

  SajagCase get _case => store.byId(widget.caseId)!;

  @override
  void initState() {
    super.initState();
    _run();
  }

  List<Evidence> _toSend() {
    final images = _case.evidence.where((e) => e.kind == EvidenceKind.image).toList();
    final audios = _case.evidence.where((e) => e.kind == EvidenceKind.audio).toList();
    // The API takes up to 6 images and 3 voice notes; keep the most recent.
    return [
      ...images.skip(images.length > 6 ? images.length - 6 : 0),
      ...audios.skip(audios.length > 3 ? audios.length - 3 : 0),
    ];
  }

  Future<void> _run() async {
    setState(() {
      _error = null;
      _feed.clear();
      _phasesSeen.clear();
    });
    _stopwatch
      ..reset()
      ..start();
    final c = _case;
    final previousLevel = c.level;
    final send = _toSend();
    final text = c.evidence.where((e) => e.kind == EvidenceKind.text).map((e) => e.text).join('\n\n');
    try {
      // Demo mode: replay the recorded real run of this sample (labelled as a replay), otherwise call the API.
      final recording = demo.match(send, c.stage);
      final result = recording != null
          ? {...await demo.replay(recording, _onProgress), '_demo_replay': recording.j['recorded_at']}
          : await api.analyze(text: text, stage: c.stage, evidence: send, onProgress: _onProgress);
      c.checks.add(CheckRun(at: DateTime.now(), analysis: result, evidenceIds: send.map((e) => e.id).toList()));
      c.agent = null; // a new check deserves fresh scripts
      final a = c.latest!.a;
      if (c.title.isEmpty) c.title = _titleFor(a);
      if (c.stage == 'after_payment' && c.status == CaseStatus.watching) c.status = CaseStatus.paid;
      await store.save(c);
      await reminders.scheduleDeadlines(c);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => CaseScreen(caseId: c.id, previousLevel: previousLevel)),
      );
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  String _titleFor(Analysis a) {
    if (a.sellerNames.isNotEmpty) return a.sellerNames.first;
    final payee = a.qr.map((q) => q['payee_name']).whereType<String>().firstOrNull;
    if (payee != null) return 'QR → $payee';
    // No shop or payee name: name the case after what was checked, e.g. "Voice note · Oct 10".
    final kinds = a.sources.map((s) => '${s['kind']}').toSet();
    final what = kinds.length == 1 && kinds.first == 'audio'
        ? tr('voiceFile')
        : kinds.length == 1 && kinds.first == 'image'
            ? tr('screenshot')
            : tr('newCheck');
    return '$what · ${DateFormat('MMM d').format(DateTime.now())}';
  }

  void _add(_FeedItem item) => setState(() => _feed.add(item));

  void _onProgress(ProgressEvent ev) {
    final d = ev.data;
    switch (ev.step) {
      case 'received':
        final parts = [
          if ((d['images'] ?? 0) > 0) '${d['images']} ${lang.ne ? 'स्क्रिनसट' : 'screenshot(s)'}',
          if ((d['audios'] ?? 0) > 0) '${d['audios']} ${lang.ne ? 'भ्वाइस नोट' : 'voice note(s)'}',
          if (d['text'] == true) lang.ne ? 'म्यासेज' : 'message',
        ];
        _add(_FeedItem(Icons.inventory_2_outlined, tr('live_received'), detail: parts.join(' · ')));
      case 'qr':
        _add(_FeedItem(Icons.qr_code_2_rounded, tr('live_qr'),
            detail: '${d['payee'] ?? '—'}${d['crc_valid'] == false ? ' · checksum ✗' : ''}', color: C.caution));
      case 'voice':
        _add(_FeedItem(Icons.graphic_eq_rounded, tr('live_voice'), detail: '“${d['transcript']}”'));
      case 'reading':
        _add(_FeedItem(Icons.auto_awesome_outlined, tr('live_reading')));
      case 'phase':
        final p = '${d['phase']}';
        if (_phasesSeen.add(p)) _add(_FeedItem(Icons.subdirectory_arrow_right_rounded, tr('phase_$p'), color: C.ink2));
      case 'writing':
        setState(() => _chars = (d['chars'] as num?)?.toInt() ?? _chars);
      case 'read':
        final sellers = (d['sellers'] as List? ?? const []).join(', ');
        _add(_FeedItem(Icons.task_alt_rounded, tr('live_read'),
            detail: '${d['events']} ${lang.ne ? 'घटना' : 'events'}${sellers.isEmpty ? '' : ' · $sellers'}'));
      case 'signal':
        final colors = severityColors('${d['severity']}');
        _add(_FeedItem(Icons.flag_outlined, '${lang.ne ? d['title_ne'] : d['title_en']}',
            detail: '“${d['quote']}” — ${tr('live_signal')}', color: colors.fg));
      case 'xray':
        _add(_FeedItem(Icons.center_focus_strong_outlined, tr('live_xray'), detail: '${d['boxes']}'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final firstImage = _case.evidence.where((e) => e.kind == EvidenceKind.image && e.bytes != null).lastOrNull;
    return Scaffold(
      appBar: AppBar(title: Text(tr('liveTitle'))),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 40), children: [
        if (firstImage != null)
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 360),
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: XRayImage(bytes: firstImage.bytes!, marks: const [], scanning: _error == null),
            ),
          ),
        const SizedBox(height: 18),
        Module(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('Gemma 4', style: T.label),
              const Spacer(),
              StreamBuilder(
                stream: Stream.periodic(const Duration(seconds: 1)),
                builder: (_, _) => Text('${_stopwatch.elapsed.inSeconds}s${_chars > 0 ? ' · $_chars chars' : ''}', style: T.meta),
              ),
            ]),
            const SizedBox(height: 8),
            ..._feed.map((f) => _FeedRow(item: f)),
            if (_error == null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(children: [
                  const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: C.ink)),
                  const SizedBox(width: 12),
                  Text(lang.ne ? 'काम गर्दैछ…' : 'Working…', style: T.small),
                ]),
              ),
          ]),
        ),
        if (_error != null) ...[
          const SizedBox(height: 14),
          Module(
            color: C.highBg,
            borderColor: C.highBg,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr('error'), style: T.h3.copyWith(color: C.high)),
              const SizedBox(height: 6),
              Text(_error!, style: T.small.copyWith(color: C.high)),
              const SizedBox(height: 12),
              Pill(tr('retry'), icon: Icons.refresh_rounded, onTap: _run),
            ]),
          ),
        ],
        const SizedBox(height: 14),
        Text(tr('verifiedNote'), style: T.meta),
      ]),
    );
  }
}

class _FeedRow extends StatelessWidget {
  const _FeedRow({required this.item});
  final _FeedItem item;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        builder: (context, t, child) => Opacity(opacity: t, child: Transform.translate(offset: Offset(0, 8 * (1 - t)), child: child)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(item.icon, size: 19, color: item.color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item.text, style: T.small.copyWith(color: item.color, fontWeight: FontWeight.w600)),
                if (item.detail != null && item.detail!.isNotEmpty) Text(item.detail!, style: T.meta),
              ]),
            ),
          ]),
        ),
      );
}
