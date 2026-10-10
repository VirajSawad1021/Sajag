// Recovery mode: a step-by-step plan after money was lost. Steps follow NRB's guidance (tell your bank/wallet
// first; escalate to NRB if unresolved) and the Cyber Bureau's process. Every contact comes from verified data.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../api.dart';
import '../demo.dart';
import '../l10n.dart';
import '../models.dart';
import '../notifications.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/contacts.dart';
import 'petition_screen.dart';

class RecoveryScreen extends StatefulWidget {
  const RecoveryScreen({super.key, required this.caseId});
  final String caseId;

  @override
  State<RecoveryScreen> createState() => _RecoveryScreenState();
}

class _RecoveryScreenState extends State<RecoveryScreen> {
  int? _open = 0;
  bool _agentBusy = false;

  SajagCase get _c => store.byId(widget.caseId)!;

  @override
  void initState() {
    super.initState();
    if (_c.status != CaseStatus.recovery) {
      _c.status = CaseStatus.recovery;
      store.save(_c);
    }
    _open = _steps.indexWhere((s) => !_c.recovery.containsKey(s.id));
  }

  late final List<_Step> _steps = [
    _Step('wallet', Icons.call_rounded, 'वालेट वा बैंकलाई तुरुन्त खबर गर्नुहोस्', 'Tell your wallet or bank now',
        'कारोबार नम्बर दिनुहोस् र आवश्यक परे सेवा रोक्न भन्नुहोस्। एपमा भएको आधिकारिक नम्बर मात्र प्रयोग गर्नुहोस्।',
        'Give them the transaction ID and ask them to block the service if needed. Use only official numbers.'),
    _Step('seller', Icons.forward_to_inbox_rounded, 'बिक्रेतालाई अन्तिम म्यासेज पठाउनुहोस्', 'Send the seller a final message',
        'मिति तोकेर लिखित म्यासेज पठाउनुहोस् र त्यसको स्क्रिनसट राख्नुहोस्।', 'Set a clear deadline in writing and screenshot it.'),
    _Step('evidence', Icons.inventory_2_outlined, 'प्रमाण सुरक्षित राख्नुहोस्', 'Keep the evidence',
        'Sajag मा केस सुरक्षित छ। मूल च्याट र रसिद नमेटाउनुहोस्।', 'Your case is saved in Sajag. Don\'t delete the original chat or receipt.'),
    _Step('facebook', Icons.report_outlined, 'Facebook मा पेज रिपोर्ट गर्नुहोस्', 'Report the page on Facebook',
        'अर्को किन्नेलाई जोगाउँछ।', 'It protects the next buyer.'),
    _Step('petition', Icons.gavel_rounded, 'साइबर ब्युरोमा उजुरी', 'File with the Cyber Bureau',
        'Gemma ले निवेदन भर्छ; तपाईं जाँचेर छाप्नुहोस् वा इमेल गर्नुहोस्।', 'Gemma fills the application; you review, then print or email it.'),
    _Step('nrb', Icons.account_balance_outlined, 'समाधान नभए नेपाल राष्ट्र बैंकमा', 'Escalate to NRB if unresolved',
        'बैंक/वालेटले समाधान नगरेमा NRB गुनासो पोर्टलमा दर्ता गर्नुहोस्।', 'If your bank or wallet doesn\'t resolve it, file on NRB\'s grievance portal.'),
  ];

  Future<void> _toggle(_Step s) async {
    final c = _c;
    if (c.recovery.containsKey(s.id)) {
      c.recovery.remove(s.id);
    } else {
      c.recovery[s.id] = DateTime.now().toIso8601String();
      final next = _steps.indexWhere((x) => !c.recovery.containsKey(x.id));
      _open = next < 0 ? null : next;
    }
    await store.save(c);
    setState(() {});
  }

  Future<void> _getScripts() async {
    setState(() => _agentBusy = true);
    try {
      final rec = demo.forAnalysis(_c.latest!.analysis);
      if (rec?.agent != null) {
        await Future.delayed(const Duration(seconds: 3));
        _c.agent = rec!.agent;
      } else {
        _c.agent = await api.agent(_c.latest!.analysis);
      }
      await store.save(_c);
    } catch (e) {
      if (mounted) toast(context, '$e');
    }
    if (mounted) setState(() => _agentBusy = false);
  }

  Widget _body(_Step s) {
    final c = _c;
    switch (s.id) {
      case 'wallet':
        final facts = c.latest?.a.facts ?? const [];
        String? fact(String field) => facts.where((f) => f['field'] == field).map((f) => '${f['value']}').firstOrNull;
        final amount = fact('price');
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (amount != null) ...[
            Text(lang.ne ? 'फोनमा भन्नुहोस्:' : 'Tell them:', style: T.label),
            Text('${lang.ne ? 'रकम' : 'Amount'}: $amount', style: T.small.copyWith(color: C.ink)),
            const SizedBox(height: 8),
          ],
          const OfficialContacts(ids: ['esewa', 'khalti', 'bank_or_wallet']),
        ]);
      case 'seller':
        final scripts = List<Map>.from(c.agent?['scripts'] ?? const []);
        if (scripts.isEmpty || c.latest?.a.stage != 'after_payment') {
          return Pill(_agentBusy ? tr('agentWorking') : (lang.ne ? 'म्यासेज लेख्न लगाउनुहोस्' : 'Write the message for me'),
              busy: _agentBusy, icon: Icons.edit_note_rounded, onTap: _getScripts);
        }
        return Column(
          children: scripts.map((m) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: RaisedCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${lang.ne ? (m['purpose_ne'] ?? m['purpose_en']) : m['purpose_en']}', style: T.label),
                    const SizedBox(height: 4),
                    Text('${m['message_ne']}', style: T.small.copyWith(color: C.ink)),
                    const SizedBox(height: 8),
                    Pill(tr('share'), icon: Icons.send_rounded, onTap: () => SharePlus.instance.share(ShareParams(text: '${m['message_ne']}'))),
                  ]),
                ),
              )).toList(),
        );
      case 'evidence':
        return Text('${c.evidence.length} ${lang.ne ? 'प्रमाण सुरक्षित' : 'items saved'} · ${DateFormat('MMM d').format(c.createdAt)}', style: T.small);
      case 'facebook':
        return Text(
          lang.ne
              ? '१. पेज खोल्नुहोस्\n२. "…" मेनु थिच्नुहोस्\n३. "Report Page" / "Find support or report" छान्नुहोस्\n४. "Scam or fraud" छान्नुहोस्\n(Facebook को मेनु एपको संस्करणअनुसार फरक हुन सक्छ।)'
              : '1. Open the page\n2. Tap the "…" menu\n3. Choose "Report Page" / "Find support or report"\n4. Pick "Scam or fraud"\n(Menu names differ between app versions.)',
          style: T.small.copyWith(color: C.ink, height: 1.7),
        );
      case 'petition':
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Pill(tr('petition'), icon: Icons.description_outlined, onTap: () {
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => PetitionScreen(caseId: c.id)));
          }),
          const SizedBox(height: 10),
          const OfficialContacts(ids: ['cyber_bureau']),
        ]);
      case 'nrb':
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const OfficialContacts(ids: ['nrb_gunaso']),
          Pill(lang.ne ? '७ दिनपछि सम्झाउनुहोस्' : 'Remind me in 7 days', primary: false, icon: Icons.alarm_add_rounded, onTap: () async {
            await reminders.remindIn(
              c,
              const Duration(days: 7),
              lang.ne ? 'Sajag: बैंक/वालेटले जवाफ दियो?' : 'Sajag: did your bank or wallet respond?',
              lang.ne ? '${c.title} — समाधान नभए NRB गुनासो पोर्टलमा दर्ता गर्न सक्नुहुन्छ।' : '${c.title} — if not resolved, you can escalate to NRB.',
              'nrb',
            );
            if (mounted) toast(context, tr('reminderSet'));
          }),
          const SizedBox(height: 6),
          Text(lang.ne ? 'यो तपाईंको आफ्नै रिमाइन्डर हो, कानुनी म्याद होइन।' : 'This is your own reminder, not a legal deadline.', style: T.meta),
        ]);
    }
    return const SizedBox();
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    final done = _steps.where((s) => c.recovery.containsKey(s.id)).length;
    return Scaffold(
      appBar: AppBar(title: Text(tr('recovery'))),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 40), children: [
        Text(c.title, style: T.h1),
        const SizedBox(height: 14),
        Module(
          color: C.cautionBg,
          borderColor: C.cautionBg,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.timer_outlined, color: C.caution),
              const SizedBox(width: 8),
              Expanded(child: Text(lang.ne ? 'छिटो कदम चाल्नुहोस्' : 'Act early', style: T.h3.copyWith(color: C.caution))),
            ]),
            const SizedBox(height: 4),
            Text(tr('recoverySub'), style: T.small.copyWith(color: C.caution)),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: done / _steps.length),
                duration: const Duration(milliseconds: 500),
                builder: (_, v, _) => LinearProgressIndicator(value: v, minHeight: 7, color: C.caution, backgroundColor: Colors.white),
              ),
            ),
            const SizedBox(height: 6),
            Text('$done / ${_steps.length} ${tr('stepsDone')}', style: T.meta.copyWith(color: C.caution)),
          ]),
        ),
        const SizedBox(height: 16),
        ..._steps.asMap().entries.map((e) {
          final i = e.key;
          final s = e.value;
          final isDone = c.recovery.containsKey(s.id);
          final open = _open == i;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: RaisedCard(
              accent: open ? C.ink : null,
              onTap: () => setState(() => _open = open ? null : i),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: isDone ? C.low : (open ? C.ink : C.module), shape: BoxShape.circle,
                        border: Border.all(color: isDone ? C.low : C.border)),
                    child: isDone
                        ? const Icon(Icons.check_rounded, size: 18, color: Colors.white)
                        : Text('${i + 1}', style: T.pill.copyWith(color: open ? Colors.white : C.ink2)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(lang.ne ? s.titleNe : s.titleEn, style: T.h3.copyWith(color: isDone ? C.muted : C.ink,
                          decoration: isDone ? TextDecoration.lineThrough : null)),
                      Text(
                        isDone
                            ? '${tr('markDone')} · ${DateFormat('MMM d, HH:mm').format(DateTime.parse(c.recovery[s.id]!))}'
                            : (lang.ne ? s.subNe : s.subEn),
                        style: T.meta,
                      ),
                    ]),
                  ),
                  Icon(s.icon, color: C.muted, size: 20),
                ]),
                AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  child: open
                      ? Padding(
                          padding: const EdgeInsets.only(top: 14),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            _body(s),
                            const SizedBox(height: 12),
                            Pill(isDone ? tr('undo') : tr('markDone'), primary: !isDone, icon: isDone ? Icons.undo_rounded : Icons.check_rounded,
                                onTap: () => _toggle(s)),
                          ]),
                        )
                      : const SizedBox(width: double.infinity),
                ),
              ]),
            ),
          );
        }),
      ]),
    );
  }
}

class _Step {
  _Step(this.id, this.icon, this.titleNe, this.titleEn, this.subNe, this.subEn);
  final String id;
  final IconData icon;
  final String titleNe, titleEn, subNe, subEn;
}
