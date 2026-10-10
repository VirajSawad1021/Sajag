// First run: three short screens — what Sajag does, that cases stay on the phone, and how to share into it.
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'home_screen.dart';

const _seenKey = 'sajag.onboarded.v1';

Future<bool> hasSeenIntro() async => (await SharedPreferences.getInstance()).getBool(_seenKey) ?? false;

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pages = PageController();
  int _index = 0;

  static const _content = [
    ('warm.webp', Icons.shield_outlined, 'intro1Title', 'intro1Body'),
    ('sage.webp', Icons.lock_outline_rounded, 'intro2Title', 'intro2Body'),
    ('orb.webp', Icons.ios_share_rounded, 'intro3Title', 'intro3Body'),
  ];

  Future<void> _finish() async {
    await (await SharedPreferences.getInstance()).setBool(_seenKey, true);
    if (mounted) Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final last = _index == _content.length - 1;
    return ListenableBuilder(
      listenable: lang,
      builder: (context, _) => Scaffold(
        body: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
              child: Row(children: [
                ClipOval(child: Image.asset('assets/art/sajag-icon.png', width: 30, height: 30)),
                const SizedBox(width: 10),
                Text('Sajag', style: T.h2),
                const Spacer(),
                TextButton(onPressed: lang.toggle, child: Text(lang.ne ? 'English' : 'नेपाली', style: T.pill)),
                TextButton(onPressed: _finish, child: Text(tr('skip'), style: T.pill.copyWith(color: C.muted))),
              ]),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pages,
                itemCount: _content.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) {
                  final (art, icon, title, body) = _content[i];
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(
                        child: ArtPanel(
                          art: art,
                          child: Center(
                            child: Container(
                              width: 96,
                              height: 96,
                              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.92), shape: BoxShape.circle),
                              child: Icon(icon, size: 44, color: C.ink),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(tr(title), style: T.h1),
                      const SizedBox(height: 10),
                      Text(tr(body), style: T.body),
                      const SizedBox(height: 12),
                    ]),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(children: [
                for (var i = 0; i < _content.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.only(right: 6),
                    width: i == _index ? 22 : 8,
                    height: 8,
                    decoration: BoxDecoration(color: i == _index ? C.ink : C.border, borderRadius: BorderRadius.circular(99)),
                  ),
                const Spacer(),
                Pill(last ? tr('start') : tr('next'), big: true, icon: last ? Icons.check_rounded : Icons.arrow_forward_rounded,
                    onTap: last
                        ? _finish
                        : () => _pages.nextPage(duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}
