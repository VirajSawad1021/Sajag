import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../api.dart';
import '../demo.dart';
import '../l10n.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../speech.dart';
import '../widgets/common.dart';
import '../widgets/speak_button.dart';
import '../widgets/xray.dart';
import 'analyzing_screen.dart';
import 'new_check_screen.dart';
import 'recovery_screen.dart';

class CaseScreen extends StatefulWidget {
  const CaseScreen({super.key, required this.caseId, this.previousLevel});
  final String caseId;
  final String? previousLevel;

  @override
  State<CaseScreen> createState() => _CaseScreenState();
}

class _CaseScreenState extends State<CaseScreen> {
  bool _agentBusy = false;
  String? _agentError;

  SajagCase? get _c => store.byId(widget.caseId);

  @override
  void dispose() {
    speaker.stop(); // don't keep talking after leaving the case
    super.dispose();
  }

  Future<void> _runAgent() async {
    final c = _c!;
    setState(() {
      _agentBusy = true;
      _agentError = null;
    });
    try {
      final rec = demo.forAnalysis(c.latest!.analysis);
      if (rec?.agent != null) {
        await Future.delayed(const Duration(seconds: 3)); // replay of the recorded agent run
        c.agent = rec!.agent;
      } else {
        c.agent = await api.agent(c.latest!.analysis);
      }
      await store.save(c);
    } catch (e) {
      _agentError = '$e';
    }
    if (mounted) setState(() => _agentBusy = false);
  }

  void _showSignal(Map<String, dynamic> s, {int? number}) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: C.canvas,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        child: _SignalDetail(s: s, number: number),
      ),
    );
  }

  Future<void> _markPaid() async {
    final c = _c!;
    c.stage = 'after_payment';
    c.status = CaseStatus.paid;
    await store.save(c);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => AnalyzingScreen(caseId: c.id)));
  }

  void _warnFamily(SajagCase c, Analysis a) {
    final ne = lang.ne;
    final lines = <String>[
      ne ? '⚠️ Sajag चेतावनी: ${c.title}' : '⚠️ Sajag warning: ${c.title}',
      tr('level_${a.level}'),
      ...a.grounded.take(4).map((s) => '• ${ne ? s['title_ne'] : s['title_en']} — “${s['quote']}”'),
      ...a.qr.where((q) => q['payee_name'] != null).map((q) => ne ? '• QR ले पैसा “${q['payee_name']}” लाई पठाउँछ' : '• The QR pays “${q['payee_name']}”'),
      '',
      ne ? 'पैसा पठाउनुअघि जाँच्नुहोस्। OTP/PIN कसैलाई नदिनुहोस्।' : 'Check before you pay. Never share an OTP or PIN.',
    ];
    SharePlus.instance.share(ShareParams(text: lines.join('\n')));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([store, lang]),
      builder: (context, _) {
        final c = _c;
        if (c == null || c.latest == null) return const Scaffold(body: SizedBox());
        final run = c.latest!;
        final a = run.a;
        final grounded = a.grounded;
        final imageSources = a.sources.where((s) => s['kind'] == 'image').toList();
        final markNumbers = <Object, int>{};
        final xrays = <Widget>[];
        for (final src in imageSources) {
          final ev = c.evidenceFor('${src['id']}', run);
          if (ev?.bytes == null) continue;
          final marks = marksFor(src, grounded);
          for (final m in marks) {
            markNumbers[m.signal] = m.number;
          }
          xrays.add(Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: XRayImage(bytes: ev!.bytes!, marks: marks, onTapMark: (m) => _showSignal(m.signal, number: m.number)),
          ));
        }
        final paid = c.stage == 'after_payment';
        final levelKey = paid && a.level == 'high' ? 'paidLevel_high' : 'level_${a.level}';
        final bodyKey = paid && a.level == 'high' ? 'paidBody_high' : 'levelBody_${a.level}';
        final colors = levelColors(a.level);

        return Scaffold(
          appBar: AppBar(
            title: Text(c.title, overflow: TextOverflow.ellipsis),
            actions: [
              PopupMenuButton<String>(
                onSelected: (v) async {
                  if (v == 'resolve') {
                    c.status = CaseStatus.resolved;
                    await store.save(c);
                  } else if (v == 'delete') {
                    await store.delete(c);
                    if (context.mounted) Navigator.of(context).pop();
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'resolve', child: Text(tr('markResolved'))),
                  PopupMenuItem(value: 'delete', child: Text(tr('delete'))),
                ],
              ),
            ],
          ),
          body: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 130), children: [
            // ---- verdict
            ArtPanel(
              art: a.level == 'low' ? 'sage.webp' : 'warm.webp',
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.94), borderRadius: BorderRadius.circular(R.card)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Tag(tr('level_${a.level}'), fg: colors.fg, bg: colors.bg, icon: Icons.shield_outlined),
                    const Spacer(),
                    Text(DateFormat('MMM d, HH:mm').format(run.at), style: T.meta),
                  ]),
                  const SizedBox(height: 10),
                  Text(tr(levelKey), style: T.h1.copyWith(color: colors.fg)),
                  const SizedBox(height: 4),
                  Text(tr(bodyKey), style: T.body),
                  if (a.summary(lang.ne).isNotEmpty && a.engine == 'gemma') ...[
                    const SizedBox(height: 10),
                    Text(a.summary(lang.ne), style: T.small.copyWith(color: C.ink)),
                  ],
                  const SizedBox(height: 12),
                  SpeakButton(id: 'case-${c.id}', text: () => Speaker.caseScript(a)),
                  if (run.analysis['_demo_replay'] != null) ...[
                    const SizedBox(height: 10),
                    Tag(lang.ne ? 'डेमो · Gemma को वास्तविक जाँचको रिप्ले (${run.analysis['_demo_replay']})' : 'Demo · replay of a real Gemma run (${run.analysis['_demo_replay']})', icon: Icons.replay_rounded),
                  ],
                  if (widget.previousLevel != null) ...[
                    const SizedBox(height: 10),
                    Tag(
                      widget.previousLevel == a.level
                          ? '${tr('riskSame')} ${tr('level_${a.level}')}'
                          : '${tr('riskChanged')}: ${tr('level_${widget.previousLevel}')} → ${tr('level_${a.level}')}',
                      icon: Icons.history_rounded,
                    ),
                  ],
                ]),
              ),
            ),
            for (final w in a.warnings) ...[
              const SizedBox(height: 8),
              Text(w, style: T.meta),
            ],

            // ---- X-Ray
            if (xrays.isNotEmpty) ...[
              const SizedBox(height: 24),
              SectionTitle(tr('xray'), icon: Icons.center_focus_strong_outlined, trailing: Text(tr('xrayHint'), style: T.meta)),
              ...xrays,
            ],

            // ---- QR
            for (final q in a.qr.where((q) => q['payee_name'] != null)) ...[
              const SizedBox(height: 12),
              RaisedCard(
                accent: grounded.any((s) => s['pattern_id'] == 'qr_payee_mismatch') ? C.high : null,
                child: Row(children: [
                  const Icon(Icons.qr_code_2_rounded, size: 34),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(tr('qrPays'), style: T.label),
                      Text('${q['payee_name']}', style: T.h2),
                      if (q['crc_valid'] == false)
                        Text(lang.ne ? 'Checksum मिलेन — QR परिवर्तन गरिएको हुन सक्छ' : 'Checksum mismatch — QR may be edited',
                            style: T.small.copyWith(color: C.high)),
                      Text(lang.ne ? 'कोडले पढेको — AI ले होइन' : 'Read by code, not by AI', style: T.meta),
                    ]),
                  ),
                ]),
              ),
            ],

            // ---- warnings
            const SizedBox(height: 24),
            SectionTitle(tr('warnings'), icon: Icons.flag_outlined),
            if (grounded.isEmpty) Module(child: Text(tr('noWarnings'), style: T.body)),
            ...grounded.map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _SignalTile(s: s, number: markNumbers[s], onTap: () => _showSignal(s, number: markNumbers[s])),
                )),

            // ---- agent
            const SizedBox(height: 14),
            _AgentPanel(c: c, busy: _agentBusy, error: _agentError, onRun: _runAgent, gemma: a.engine == 'gemma'),

            // ---- follow-ups
            if (a.deadlines.any((d) => d['due'] != null)) ...[
              const SizedBox(height: 24),
              SectionTitle(tr('followUps'), icon: Icons.notifications_active_outlined),
              ...a.deadlines.where((d) => d['due'] != null).map((d) {
                final due = DateTime.tryParse('${d['due']}');
                final future = due != null && due.isAfter(DateTime.now());
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: RaisedCard(
                    child: Row(children: [
                      Icon(future ? Icons.alarm_on_rounded : Icons.alarm_rounded, color: future ? C.low : C.caution),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${lang.ne ? (d['what_ne'] ?? d['what_en']) : d['what_en']}', style: T.small.copyWith(color: C.ink, fontWeight: FontWeight.w600)),
                          Text(
                            '${d['due']} · ${future ? tr('reminderSet') : (lang.ne ? 'मिति नाघिसक्यो' : 'date has passed')}',
                            style: T.meta,
                          ),
                        ]),
                      ),
                    ]),
                  ),
                );
              }),
            ],

            // ---- timeline
            if (a.events.isNotEmpty) ...[
              const SizedBox(height: 24),
              SectionTitle(tr('timeline'), icon: Icons.timeline_rounded),
              Module(padding: const EdgeInsets.fromLTRB(16, 14, 16, 4), child: _Timeline(events: a.events)),
            ],

            // ---- next steps
            const SizedBox(height: 24),
            SectionTitle(tr('nextSteps'), icon: Icons.checklist_rounded),
            Module(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                children: a.nextSteps.asMap().entries.map((e) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Container(
                          width: 22,
                          height: 22,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(color: C.ink, shape: BoxShape.circle),
                          child: Text('${e.key + 1}', style: T.pill.copyWith(color: Colors.white, fontSize: 11)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Text('${lang.ne ? e.value['text_ne'] : e.value['text_en']}', style: T.small.copyWith(color: C.ink))),
                      ]),
                    )).toList(),
              ),
            ),

            // ---- evidence text
            const SizedBox(height: 24),
            SectionTitle(tr('evidence'), icon: Icons.description_outlined),
            ...a.sources.where((s) => '${s['transcript']}'.isNotEmpty).map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Module(
                    padding: const EdgeInsets.all(14),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(
                        s['transcript_by'] == 'model'
                            ? tr('readByGemma')
                            : s['transcript_by'] == 'asr'
                                ? tr('readByAsr')
                                : (s['filename'] ?? 'text').toString(),
                        style: T.label,
                      ),
                      const SizedBox(height: 6),
                      SelectableText('${s['transcript']}', style: T.small.copyWith(color: C.ink)),
                    ]),
                  ),
                )),
            const SizedBox(height: 10),
            Text(tr('disclaimer'), style: T.meta, textAlign: TextAlign.center),
          ]),
          bottomNavigationBar: SafeArea(
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              decoration: const BoxDecoration(color: C.canvas, border: Border(top: BorderSide(color: C.border))),
              child: Row(children: [
                Expanded(
                  child: Pill(tr('addReply'), primary: false, icon: Icons.reply_rounded, onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => NewCheckScreen(caseId: c.id)));
                  }),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: paid
                      ? Pill(tr('startRecovery'), danger: true, icon: Icons.healing_rounded, onTap: () {
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => RecoveryScreen(caseId: c.id)));
                        })
                      : Pill(tr('iPaid'), icon: Icons.payments_outlined, onTap: _markPaid),
                ),
                IconButton(
                  tooltip: tr('warnFamily'),
                  icon: const Icon(Icons.family_restroom_rounded),
                  onPressed: () => _warnFamily(c, a),
                ),
              ]),
            ),
          ),
        );
      },
    );
  }
}

class _SignalTile extends StatelessWidget {
  const _SignalTile({required this.s, required this.number, required this.onTap});
  final Map<String, dynamic> s;
  final int? number;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = severityColors('${s['severity']}');
    return RaisedCard(
      onTap: onTap,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: number != null ? colors.fg : colors.bg, shape: BoxShape.circle),
          child: number != null
              ? Text('$number', style: T.pill.copyWith(color: Colors.white))
              : Icon(s['origin'] == 'qr' ? Icons.qr_code_2_rounded : Icons.flag_outlined, size: 15, color: colors.fg),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${lang.ne ? s['title_ne'] : s['title_en']}', style: T.h3),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: colors.bg, borderRadius: BorderRadius.circular(10)),
              child: Text('“${s['quote']}”', style: T.small.copyWith(color: colors.fg, fontWeight: FontWeight.w600)),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _SignalDetail extends StatelessWidget {
  const _SignalDetail({required this.s, this.number});
  final Map<String, dynamic> s;
  final int? number;

  @override
  Widget build(BuildContext context) {
    final colors = severityColors('${s['severity']}');
    final unknowns = List<String>.from(s['unknowns_en'] ?? const []);
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        if (number != null) ...[Tag('$number', fg: Colors.white, bg: colors.fg), const SizedBox(width: 8)],
        Tag('${s['severity']}', fg: colors.fg, bg: colors.bg),
        const SizedBox(width: 8),
        if (s['origin'] == 'qr') Tag(lang.ne ? 'कोडले पत्ता लगायो' : 'Detected by code'),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: Text('${lang.ne ? s['title_ne'] : s['title_en']}', style: T.h2)),
        SpeakIcon(
          id: 'signal-${s['pattern_id']}-${s['quote']}',
          ne: '${s['title_ne']}। ${s['explanation_ne'] ?? s['explanation_en'] ?? ''}',
          en: '${s['title_en']}. ${s['explanation_en'] ?? ''}',
        ),
      ]),
      const SizedBox(height: 10),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: colors.bg, borderRadius: BorderRadius.circular(R.field)),
        child: Text('“${s['quote']}”', style: T.bodyInk.copyWith(color: colors.fg, fontWeight: FontWeight.w600)),
      ),
      const SizedBox(height: 12),
      Text('${lang.ne ? (s['explanation_ne'] ?? s['explanation_en']) : s['explanation_en']}', style: T.bodyInk),
      if (unknowns.isNotEmpty) ...[
        const SizedBox(height: 12),
        Text(tr('unknowns'), style: T.label),
        ...unknowns.map((u) => Text('• $u', style: T.small)),
      ],
      if ('${s['not_always_scam_en'] ?? ''}'.isNotEmpty) ...[
        const SizedBox(height: 12),
        Text(tr('notAlways'), style: T.label),
        Text('${s['not_always_scam_en']}', style: T.small),
      ],
    ]);
  }
}

class _AgentPanel extends StatelessWidget {
  const _AgentPanel({required this.c, required this.busy, required this.error, required this.onRun, required this.gemma});
  final SajagCase c;
  final bool busy, gemma;
  final String? error;
  final VoidCallback onRun;

  @override
  Widget build(BuildContext context) {
    final agent = c.agent;
    // A friend/relative asking for money: verify the person, not a shop.
    final friend = c.latest?.a.grounded.any((s) => s['pattern_id'] == 'friend_impersonation') ?? false;
    return Module(
      color: C.raised,
      borderColor: C.ink,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          ClipOval(child: Image.asset('assets/art/orb.webp', width: 26, height: 26, fit: BoxFit.cover)),
          const SizedBox(width: 10),
          Text(tr('agent'), style: T.h2),
          const Spacer(),
          if (agent != null && List.from(agent['trace'] ?? const []).isNotEmpty) Tag(lang.ne ? 'Gemma 4 + वेब खोज' : 'Gemma 4 + web search'),
        ]),
        const SizedBox(height: 10),
        if (agent == null) ...[
          Text(
            friend
                ? (lang.ne
                    ? 'एजेन्टले साथी साँच्चै हुन् कि होइनन् भनेर पुष्टि गर्ने प्रश्न र म्यासेज लेख्छ — उहाँलाई मात्र थाहा हुने प्रश्न, पुरानो नम्बरमा फोन, र कोड नदिने जवाफ।'
                    : 'The agent writes messages to check it is really them — a question only they would know, a call on their usual number, and a polite refusal to share codes.')
                : (lang.ne
                    ? 'एजेन्टले पसल/पेजबारे अनलाइन खोज्छ, मूल्य मिलाउँछ, र बिक्रेतालाई सोध्ने प्रश्न लेख्छ। कसैको व्यक्तिगत नाम वा नम्बर खोज्दैन।'
                    : 'The agent searches the web about the shop/page, compares the price, and writes questions to ask the seller. It never searches private names or numbers.'),
            style: T.small,
          ),
          const SizedBox(height: 12),
          Pill(busy ? tr('agentWorking') : tr(friend ? 'agentRunFriend' : 'agentRun'), busy: busy,
              icon: friend ? Icons.verified_user_outlined : Icons.travel_explore_rounded, onTap: gemma ? onRun : null),
          if (error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(error!, style: T.small.copyWith(color: C.high))),
        ] else ...[
          for (final t in List<String>.from(agent['trace'] ?? const []))
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(children: [
                const Icon(Icons.search_rounded, size: 15, color: C.muted),
                const SizedBox(width: 6),
                Expanded(child: Text(t.replaceFirst('web_search: ', ''), style: T.meta)),
              ]),
            ),
          const SizedBox(height: 6),
          Text('${lang.ne ? (agent['online_summary_ne'] ?? agent['online_summary_en']) : agent['online_summary_en']}', style: T.small.copyWith(color: C.ink)),
          const SizedBox(height: 16),
          Text(tr('scripts'), style: T.h3),
          Text(tr('scriptsHelp'), style: T.meta),
          const SizedBox(height: 8),
          ...List<Map>.from(agent['scripts'] ?? const []).map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: C.module, borderRadius: BorderRadius.circular(R.card), border: Border.all(color: C.border)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${lang.ne ? (s['purpose_ne'] ?? s['purpose_en']) : s['purpose_en']}', style: T.label),
                    const SizedBox(height: 6),
                    Text('${s['message_ne']}', style: T.bodyInk),
                    if (!lang.ne && '${s['message_en'] ?? ''}'.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text('${s['message_en']}', style: T.meta),
                    ],
                    const SizedBox(height: 10),
                    Row(children: [
                      Pill(tr('copy'), primary: false, icon: Icons.copy_rounded, onTap: () {
                        Clipboard.setData(ClipboardData(text: '${s['message_ne']}'));
                        toast(context, tr('copied'));
                      }),
                      const SizedBox(width: 8),
                      Pill(tr('share'), icon: Icons.send_rounded, onTap: () => SharePlus.instance.share(ShareParams(text: '${s['message_ne']}'))),
                    ]),
                  ]),
                ),
              )),
          if ('${agent['what_changes_risk_en'] ?? ''}'.isNotEmpty)
            Text('${lang.ne ? (agent['what_changes_risk_ne'] ?? agent['what_changes_risk_en']) : agent['what_changes_risk_en']}',
                style: T.small.copyWith(fontStyle: FontStyle.italic)),
        ],
      ]),
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.events});
  final List<Map<String, dynamic>> events;

  @override
  Widget build(BuildContext context) => Column(
        children: events.asMap().entries.map((e) {
          final last = e.key == events.length - 1;
          final ev = e.value;
          final changed = '${ev['type']}' == 'terms_changed' || '${ev['type']}' == 'extra_fee_demanded';
          return IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Column(children: [
                Container(
                  width: 12,
                  height: 12,
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(color: changed ? C.high : C.ink, shape: BoxShape.circle),
                ),
                if (!last) Expanded(child: Container(width: 1.5, color: C.border)),
              ]),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if ('${ev['when'] ?? ''}'.isNotEmpty && ev['when'] != null) Text('${ev['when']}', style: T.meta),
                    Text('${lang.ne ? (ev['summary_ne'] ?? ev['summary_en']) : ev['summary_en']}',
                        style: T.small.copyWith(color: changed ? C.high : C.ink, fontWeight: changed ? FontWeight.w600 : null)),
                  ]),
                ),
              ),
            ]),
          );
        }).toList(),
      );
}
