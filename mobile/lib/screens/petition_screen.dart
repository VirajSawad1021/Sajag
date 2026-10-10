// Cyber Bureau application: Gemma fills the fields from the case; the user reviews and edits every field;
// the server renders a print-ready PDF (formal Nepali, B.S. date, numbered annexes). Sajag never submits it.
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api.dart';
import '../demo.dart';
import '../l10n.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';

class PetitionScreen extends StatefulWidget {
  const PetitionScreen({super.key, required this.caseId});
  final String caseId;

  @override
  State<PetitionScreen> createState() => _PetitionScreenState();
}

class _PetitionScreenState extends State<PetitionScreen> {
  final _story = TextEditingController();
  final Map<String, TextEditingController> _who = {
    for (final k in ['name', 'permanent_address', 'current_address', 'phone', 'email']) k: TextEditingController(),
  };
  final Map<String, TextEditingController> _f = {};
  Map<String, dynamic>? _fields;
  bool _drafting = false, _rendering = false;
  String? _error;

  SajagCase get _c => store.byId(widget.caseId)!;

  static const _textFields = ['amount', 'payment_date', 'payment_method', 'transaction_id', 'receiver_name', 'receiver_id'];
  static const _listFields = ['seller_names', 'seller_contacts', 'urls'];

  @override
  void initState() {
    super.initState();
    for (final k in _who.keys) {
      _who[k]!.text = store.profile[k] ?? '';
    }
    // A voice note is often the victim's own account — prefill the story with it.
    final voice = _c.latest?.a.sources.where((s) => s['transcript_by'] == 'asr').map((s) => '${s['transcript']}').join('\n');
    if (voice != null && voice.isNotEmpty) _story.text = voice;
    if (_c.petition != null) _load(_c.petition!);
  }

  void _load(Map<String, dynamic> fields) {
    _fields = fields;
    for (final k in _textFields) {
      _f[k] = TextEditingController(text: '${fields[k] ?? ''}');
    }
    for (final k in _listFields) {
      _f[k] = TextEditingController(text: List<String>.from(fields[k] ?? const []).join(', '));
    }
    _f['narrative_ne'] = TextEditingController(text: '${fields['narrative_ne'] ?? ''}');
  }

  Future<void> _draft() async {
    setState(() {
      _drafting = true;
      _error = null;
    });
    try {
      final rec = demo.forAnalysis(_c.latest!.analysis);
      final Map<String, dynamic> fields;
      if (rec?.petition != null) {
        await Future.delayed(const Duration(seconds: 3)); // replay of the recorded draft
        fields = rec!.petition!;
      } else {
        fields = await api.petitionDraft(_c.latest!.analysis, _story.text);
      }
      _load(fields);
      _c.petition = fields;
      await store.save(_c);
    } catch (e) {
      _error = '$e';
    }
    if (mounted) setState(() => _drafting = false);
  }

  Map<String, dynamic> _collect() {
    final out = Map<String, dynamic>.from(_fields ?? {});
    for (final k in _textFields) {
      final v = _f[k]!.text.trim();
      out[k] = v.isEmpty ? null : v;
    }
    for (final k in _listFields) {
      out[k] = _f[k]!.text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    }
    out['narrative_ne'] = _f['narrative_ne']!.text.trim();
    if (out['payment_date'] != null && DateTime.tryParse('${out['payment_date']}') == null) out['payment_date'] = null;
    return out;
  }

  Future<void> _makePdf() async {
    setState(() {
      _rendering = true;
      _error = null;
    });
    try {
      final who = {for (final e in _who.entries) e.key: e.value.text.trim()};
      await store.saveProfile(who);
      final fields = _collect();
      _c.petition = fields;
      await store.save(_c);
      final images = _c.evidence.where((e) => e.kind == EvidenceKind.image).toList();
      final pdf = await api.petitionPdf(fields, who, images);
      await SharePlus.instance.share(ShareParams(
        files: [XFile.fromData(pdf, mimeType: 'application/pdf', name: 'sajag-cyber-bureau-application.pdf')],
        fileNameOverrides: ['sajag-cyber-bureau-application.pdf'],
        subject: 'विद्युतीय माध्यम सम्बद्ध ठगी सम्बन्धमा निवेदन',
      ));
    } catch (e) {
      _error = '$e';
    }
    if (mounted) setState(() => _rendering = false);
  }

  Widget _field(String key, String label, {int lines = 1}) {
    final found = (_fields?['found_in_evidence'] as Map?)?[key];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(label, style: T.label),
          const Spacer(),
          if (found == true) Tag(tr('foundInEvidence'), fg: C.low, bg: C.lowBg, icon: Icons.verified_outlined),
          if (found == false) Tag(tr('checkThis'), fg: C.caution, bg: C.cautionBg, icon: Icons.help_outline_rounded),
        ]),
        const SizedBox(height: 6),
        TextField(controller: _f[key], minLines: lines, maxLines: lines == 1 ? 1 : 12),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ne = lang.ne;
    return Scaffold(
      appBar: AppBar(title: Text(tr('petition'))),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 40), children: [
        ArtPanel(
          art: 'sage.webp',
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.94), borderRadius: BorderRadius.circular(R.card)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr('petition'), style: T.h2),
              Text(tr('petitionSub'), style: T.small),
              const SizedBox(height: 8),
              Text(tr('petitionHow'), style: T.meta),
            ]),
          ),
        ),
        const SizedBox(height: 18),
        Text(tr('yourStory'), style: T.label),
        const SizedBox(height: 6),
        TextField(controller: _story, minLines: 3, maxLines: 8),
        const SizedBox(height: 12),
        Pill(_drafting ? tr('filling') : tr('fillWithGemma'), busy: _drafting, icon: Icons.auto_awesome_outlined, onTap: _draft),
        if (_error != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(_error!, style: T.small.copyWith(color: C.high))),
        if (_fields != null) ...[
          const SizedBox(height: 22),
          SectionTitle(ne ? 'आर्थिक कारोबार' : 'Payment', icon: Icons.receipt_long_outlined),
          _field('amount', ne ? 'रकम (रु.)' : 'Amount (Rs.)'),
          _field('payment_date', ne ? 'भुक्तानी मिति (YYYY-MM-DD)' : 'Payment date (YYYY-MM-DD)'),
          _field('payment_method', ne ? 'वालेट / बैंक' : 'Wallet / bank'),
          _field('transaction_id', ne ? 'कारोबार नम्बर' : 'Transaction ID'),
          _field('receiver_name', ne ? 'रकम प्राप्त गर्ने' : 'Receiver name'),
          _field('receiver_id', ne ? 'प्राप्तकर्ताको खाता/ID' : 'Receiver account / ID'),
          const SizedBox(height: 6),
          SectionTitle(ne ? 'पेज / व्यक्ति' : 'Page / person', icon: Icons.storefront_outlined),
          _field('seller_names', ne ? 'पेज/पसलको नाम (अल्पविरामले छुट्याउनुहोस्)' : 'Page/shop names (comma separated)'),
          _field('seller_contacts', ne ? 'सम्पर्क नम्बर / आईडी' : 'Phone numbers / handles'),
          _field('urls', ne ? 'लिङ्क (URL) — आवश्यक' : 'Links (URLs) — required by the Bureau'),
          const SizedBox(height: 6),
          SectionTitle(ne ? 'घटनाको विवरण' : 'What happened', icon: Icons.notes_rounded),
          _field('narrative_ne', ne ? 'Gemma ले लेखेको — आवश्यक भए सच्याउनुहोस्' : 'Written by Gemma — edit as needed', lines: 6),
          const SizedBox(height: 6),
          SectionTitle(tr('yourDetails'), icon: Icons.person_outline_rounded),
          for (final (k, label) in [
            ('name', tr('name')),
            ('permanent_address', tr('permAddr')),
            ('current_address', tr('currAddr')),
            ('phone', tr('phone')),
            ('email', tr('emailAddr')),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TextField(controller: _who[k], decoration: InputDecoration(labelText: label)),
            ),
          Text(ne ? 'तपाईंको विवरण यो फोनमा मात्र सुरक्षित हुन्छ।' : 'Your details are saved on this phone only.', style: T.meta),
          const SizedBox(height: 16),
          Pill(tr('makePdf'), big: true, busy: _rendering, icon: Icons.picture_as_pdf_outlined, onTap: _makePdf),
          const SizedBox(height: 10),
          Pill(ne ? 'साइबर ब्युरोलाई इमेल' : 'Email the Cyber Bureau', primary: false, icon: Icons.mail_outline_rounded, onTap: () {
            launchUrl(Uri.parse('mailto:cyberbureau@nepalpolice.gov.np?subject=${Uri.encodeComponent('विद्युतीय माध्यम सम्बद्ध ठगी सम्बन्धमा निवेदन')}'));
          }),
          const SizedBox(height: 6),
          Text(ne ? 'इमेलमा PDF, परिचयपत्रको प्रतिलिपि र स्क्रिनसट आफैं जोड्नुहोस्।' : 'Attach the PDF, your ID copy and the screenshots to the email yourself.', style: T.meta),
        ],
      ]),
    );
  }
}
