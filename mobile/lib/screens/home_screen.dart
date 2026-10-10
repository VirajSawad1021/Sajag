// Casebook: every case on this phone, with status, risk and anything due today.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../demo.dart';
import '../l10n.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'case_screen.dart';
import 'emergency_screen.dart';
import 'new_check_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([lang, demo]),
      builder: (context, _) => Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: store,
          builder: (context, _) {
            final due = _dueToday();
            return CustomScrollView(slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                sliver: SliverList.list(children: [
                  _TopBar(),
                  const SizedBox(height: 18),
                  _Hero(),
                  const SizedBox(height: 14),
                  _EmergencyCard(),
                  const SizedBox(height: 10),
                  _FriendCard(),
                  if (due.isNotEmpty) ...[
                    const SizedBox(height: 22),
                    SectionTitle(tr('dueToday'), icon: Icons.notifications_none_rounded),
                    ...due.map((d) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: RaisedCard(
                            accent: C.caution,
                            onTap: () => _open(context, d.$1),
                            child: Row(children: [
                              const Icon(Icons.schedule_rounded, color: C.caution),
                              const SizedBox(width: 10),
                              Expanded(child: Text('${d.$1.title} — ${d.$2}', style: T.small.copyWith(color: C.ink))),
                              const Icon(Icons.chevron_right_rounded, color: C.muted),
                            ]),
                          ),
                        )),
                  ],
                  const SizedBox(height: 26),
                  SectionTitle(tr('casebook'),
                      trailing: store.cases.isEmpty ? null : Text('${store.cases.length}', style: T.meta)),
                  if (store.cases.isEmpty)
                    Module(child: Text(tr('casebookEmpty'), style: T.body))
                  else
                    ...store.cases.map((c) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _CaseTile(c: c, onTap: () => _open(context, c)),
                        )),
                  const SizedBox(height: 24),
                  Text(tr('disclaimer'), style: T.meta, textAlign: TextAlign.center),
                  const SizedBox(height: 90),
                ]),
              ),
            ]);
          },
        ),
      ),
      floatingActionButton: Pill(tr('newCheck'), icon: Icons.add_rounded, big: true, onTap: () {
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NewCheckScreen()));
      }),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    ));
  }

  void _open(BuildContext context, SajagCase c) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => CaseScreen(caseId: c.id)));

  List<(SajagCase, String)> _dueToday() {
    final today = DateTime.now();
    final out = <(SajagCase, String)>[];
    for (final c in store.cases.where((c) => c.status != CaseStatus.resolved)) {
      for (final d in c.latest?.a.deadlines ?? const <Map<String, dynamic>>[]) {
        final due = DateTime.tryParse('${d['due'] ?? ''}');
        if (due != null && d['grounded'] == true && !due.isAfter(DateTime(today.year, today.month, today.day))) {
          out.add((c, '${lang.ne ? (d['what_ne'] ?? d['what_en']) : d['what_en']}'));
        }
      }
    }
    return out;
  }
}

class _TopBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Row(children: [
        ClipRRect(borderRadius: BorderRadius.circular(9), child: Image.asset('assets/art/sajag-icon.png', width: 34, height: 34)),
        const SizedBox(width: 10),
        Text('Sajag', style: T.h2),
        const SizedBox(width: 6),
        Text('सजग', style: T.h2.copyWith(color: C.muted, fontWeight: FontWeight.w500)),
        if (demo.enabled) ...[const SizedBox(width: 8), const Tag('DEMO', fg: C.caution, bg: C.cautionBg)],
        const Spacer(),
        Semantics(
          button: true,
          container: true,
          label: lang.ne ? 'Switch to English' : 'नेपालीमा बदल्नुहोस्',
          excludeSemantics: true,
          onTap: lang.toggle,
          child: Material(
          color: C.pill,
          shape: const StadiumBorder(),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: lang.toggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              child: Text(lang.ne ? 'EN' : 'नेपाली', style: T.pill),
            ),
          ),
        )),
        IconButton(
          tooltip: tr('settings'),
          icon: const Icon(Icons.tune_rounded),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
        ),
      ]);
}

class _Hero extends StatelessWidget {
  @override
  Widget build(BuildContext context) => ArtPanel(
        art: 'warm.webp',
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.93), borderRadius: BorderRadius.circular(R.card)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tr('tagline'), style: T.hero),
            const SizedBox(height: 10),
            Text(tr('heroSub'), style: T.body),
            const SizedBox(height: 16),
            Wrap(spacing: 8, runSpacing: 8, children: [
              Tag(lang.ne ? 'स्क्रिनसट' : 'Screenshots', icon: Icons.image_outlined),
              Tag(lang.ne ? 'भुक्तानी QR' : 'Payment QR', icon: Icons.qr_code_2_rounded),
              Tag(lang.ne ? 'भ्वाइस नोट' : 'Voice notes', icon: Icons.mic_none_rounded),
              Tag(lang.ne ? 'बैंक SMS' : 'Bank SMS', icon: Icons.sms_outlined),
            ]),
          ]),
        ),
      );
}

class _FriendCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) => RaisedCard(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NewCheckScreen(mode: CheckMode.friend))),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(color: C.infoBg, shape: BoxShape.circle),
            child: const Icon(Icons.people_alt_outlined, color: C.info),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr('friendCard'), style: T.h3),
              Text(tr('friendCardSub'), style: T.small),
            ]),
          ),
          const Icon(Icons.chevron_right_rounded, color: C.muted),
        ]),
      );
}

class _EmergencyCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) => RaisedCard(
        accent: C.high,
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EmergencyScreen())),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(color: C.highBg, shape: BoxShape.circle),
            child: const Icon(Icons.priority_high_rounded, color: C.high),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr('emergency'), style: T.h3.copyWith(color: C.high)),
              Text(tr('emergencySub'), style: T.small),
            ]),
          ),
          const Icon(Icons.chevron_right_rounded, color: C.high),
        ]),
      );
}

class _CaseTile extends StatelessWidget {
  const _CaseTile({required this.c, required this.onTap});
  final SajagCase c;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final level = c.level ?? 'insufficient';
    final colors = levelColors(level);
    final firstImage = c.evidence.where((e) => e.kind == EvidenceKind.image && e.bytes != null).firstOrNull;
    return RaisedCard(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      child: Row(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(R.field),
          child: SizedBox(
            width: 56,
            height: 56,
            child: firstImage != null
                ? Image.memory(firstImage.bytes!, fit: BoxFit.cover, alignment: Alignment.topCenter)
                : Container(color: C.module, child: const Icon(Icons.chat_bubble_outline_rounded, color: C.muted)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(c.title.isEmpty ? tr('newCheck') : c.title, style: T.h3, maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Tag(tr('level_$level'), fg: colors.fg, bg: colors.bg),
              Tag(tr('status_${c.status.name}')),
              Text(DateFormat('MMM d').format(c.updatedAt), style: T.meta),
            ]),
          ]),
        ),
        const Icon(Icons.chevron_right_rounded, color: C.muted),
      ]),
    );
  }
}
