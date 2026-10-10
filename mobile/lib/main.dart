import 'package:flutter/material.dart';

import 'demo.dart';
import 'l10n.dart';
import 'notifications.dart';
import 'delivery.dart';
import 'screens/case_screen.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/new_check_screen.dart';
import 'share_receiver.dart';
import 'store.dart';
import 'theme.dart';

final navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await store.load();
  await demo.load();
  await lang.load();
  await reminders.init();
  reminders.onOpenCase = (id, action) {
    final c = store.byId(id);
    final nav = navigatorKey.currentState;
    if (c == null || nav == null) return;
    if (action == 'arrived' || action == 'not_arrived') {
      answerDelivery(nav, c, arrived: action == 'arrived');
    } else {
      nav.push(MaterialPageRoute(builder: (_) => CaseScreen(caseId: c.id)));
    }
  };
  final seenIntro = await hasSeenIntro();
  runApp(SajagApp(showIntro: !seenIntro));
  WidgetsBinding.instance.addPostFrameCallback((_) => reminders.handleLaunch());
  // Things shared into Sajag from Messenger, Gallery, WhatsApp, SMS… open a pre-filled new check.
  shareReceiver.start((evidence) {
    if (evidence.isEmpty) return;
    void open() => navigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => NewCheckScreen(initial: evidence)));
    // A share that *launches* the app arrives before the first screen exists; open it once a frame is drawn.
    if (navigatorKey.currentState != null) {
      open();
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => open());
    }
  });
}

class SajagApp extends StatelessWidget {
  const SajagApp({super.key, this.showIntro = false});
  final bool showIntro;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sajag',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: buildTheme(),
      home: showIntro ? const OnboardingScreen() : const HomeScreen(),
    );
  }
}
