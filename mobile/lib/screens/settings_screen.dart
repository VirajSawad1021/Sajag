import 'package:flutter/material.dart';

import '../api.dart';
import '../demo.dart';
import '../l10n.dart';
import '../models.dart';
import '../notifications.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _server = TextEditingController(text: store.serverOverride ?? '');
  bool? _ok;
  bool _testing = false;

  Future<void> _test() async {
    setState(() => _testing = true);
    await store.setServer(_server.text);
    final ok = await api.health();
    if (mounted) {
      setState(() {
        _ok = ok;
        _testing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ne = lang.ne;
    return Scaffold(
      appBar: AppBar(title: Text(tr('settings'))),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 40), children: [
        Text(tr('serverUrl'), style: T.label),
        const SizedBox(height: 6),
        TextField(controller: _server, decoration: InputDecoration(hintText: apiBase)),
        const SizedBox(height: 6),
        Text(
          ne
              ? 'फोन र ल्यापटप एउटै Wi-Fi मा हुँदा: http://<ल्यापटपको IP>:8000'
              : 'Phone and laptop on the same Wi-Fi: http://<laptop IP>:8000',
          style: T.meta,
        ),
        const SizedBox(height: 10),
        Row(children: [
          Pill(tr('testConnection'), busy: _testing, icon: Icons.wifi_tethering_rounded, onTap: _test),
          const SizedBox(width: 12),
          if (_ok == true) Tag(tr('connected'), fg: C.low, bg: C.lowBg, icon: Icons.check_rounded),
          if (_ok == false) Tag(ne ? 'जडान भएन' : 'Not reachable', fg: C.high, bg: C.highBg),
        ]),
        const SizedBox(height: 26),
        Text(ne ? 'भाषा' : 'Language', style: T.label),
        const SizedBox(height: 6),
        Pill(ne ? 'Switch to English' : 'नेपालीमा बदल्नुहोस्', primary: false, icon: Icons.translate_rounded, onTap: () => setState(lang.toggle)),
        const SizedBox(height: 26),
        Text(ne ? 'डेमो' : 'Demo', style: T.label),
        const SizedBox(height: 6),
        Module(
          padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: demo.enabled,
            activeThumbColor: C.ink,
            title: Text(ne ? 'डेमो मोड' : 'Demo mode', style: T.h3),
            subtitle: Text(
              ne
                  ? 'नमुनाहरूले Gemma को रेकर्ड गरिएको वास्तविक जाँच रिप्ले गर्छन् — इन्टरनेट नचाहिने, र "डेमो" भनी देखाइन्छ।'
                  : 'Samples replay recorded real Gemma runs — no internet needed, always labelled "Demo".',
              style: T.meta,
            ),
            onChanged: (v) async {
              await demo.setEnabled(v);
              setState(() {});
            },
          ),
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          Pill(ne ? 'डेमो केस थप्नुहोस्' : 'Load demo cases', primary: false, icon: Icons.playlist_add_rounded, onTap: () async {
            await demo.loadCases();
            if (context.mounted) toast(context, ne ? 'डेमो केस थपियो' : 'Demo cases added');
          }),
          Pill(ne ? 'सबै केस मेटाउनुहोस्' : 'Clear all cases', primary: false, icon: Icons.delete_sweep_outlined, onTap: () async {
            await demo.reset();
            if (context.mounted) toast(context, ne ? 'केसहरू मेटाइए' : 'Cases cleared');
          }),
        ]),
        const SizedBox(height: 8),
        Pill(ne ? 'फलोअप सूचना कस्तो देखिन्छ हेर्नुहोस्' : 'Preview a follow-up notification', primary: false, icon: Icons.notifications_none_rounded,
            onTap: () async {
          final c = store.cases.firstOrNull ?? SajagCase(title: 'Nepal Shoes Corner');
          await reminders.showNow(
            c,
            ne ? 'Sajag: आज फलोअप गर्ने दिन' : 'Sajag: follow-up due today',
            ne ? '${c.title} ले आज डेलिभरी गर्ने भनेको थियो। सामान आयो?' : '${c.title} promised delivery today. Did it arrive?',
          );
        }),
        const SizedBox(height: 26),
        Module(child: Text(tr('privacyNote'), style: T.small)),
      ]),
    );
  }
}
