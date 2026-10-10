import 'package:flutter/material.dart';

import 'demo.dart';
import 'l10n.dart';
import 'notifications.dart';
import 'screens/case_screen.dart';
import 'screens/home_screen.dart';
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
  reminders.onOpenCase = (id) {
    final c = store.byId(id);
    if (c != null) navigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => CaseScreen(caseId: c.id)));
  };
  runApp(const SajagApp());
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
  const SajagApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sajag',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: buildTheme(),
      home: const HomeScreen(),
    );
  }
}
