// Official contact cards. Numbers come only from the server's verified resources file, each with its source
// and the date it was checked — never from chats, the model, or this app's code.
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api.dart';
import '../l10n.dart';
import '../theme.dart';
import 'common.dart';

class OfficialContacts extends StatefulWidget {
  const OfficialContacts({super.key, required this.ids});
  final List<String> ids;

  @override
  State<OfficialContacts> createState() => _OfficialContactsState();
}

class _OfficialContactsState extends State<OfficialContacts> {
  late final Future<List<Map<String, dynamic>>> _future = api.resources();

  @override
  Widget build(BuildContext context) => FutureBuilder(
        future: _future,
        builder: (context, snap) {
          if (snap.hasError) return Text('${snap.error}', style: T.small.copyWith(color: C.high));
          if (!snap.hasData) return const LinearProgressIndicator(minHeight: 2, color: C.ink);
          final items = widget.ids.map((id) => snap.data!.where((r) => r['id'] == id).firstOrNull).whereType<Map<String, dynamic>>();
          return Column(children: items.map((r) => Padding(padding: const EdgeInsets.only(bottom: 8), child: ContactCard(r: r))).toList());
        },
      );
}

class ContactCard extends StatelessWidget {
  const ContactCard({super.key, required this.r});
  final Map<String, dynamic> r;

  @override
  Widget build(BuildContext context) {
    final phones = List<String>.from(r['phones'] ?? const []);
    final emails = List<String>.from(r['emails'] ?? const []);
    final url = r['url'] as String?;
    return RaisedCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${lang.ne ? r['name_ne'] : r['name_en']}', style: T.h3),
        const SizedBox(height: 4),
        Text('${lang.ne ? r['note_ne'] : r['note_en']}', style: T.small),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          ...phones.map((p) => Pill('${tr('call')} $p', icon: Icons.call_rounded, onTap: () => launchUrl(Uri.parse('tel:${p.replaceAll('-', '')}')))),
          ...emails.map((e) => Pill(e, primary: false, icon: Icons.mail_outline_rounded, onTap: () => launchUrl(Uri.parse('mailto:$e')))),
          if (url != null) Pill(tr('open'), primary: false, icon: Icons.open_in_new_rounded, onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)),
        ]),
        const SizedBox(height: 8),
        Text(
          r['last_checked'] != null
              ? '${tr('checkedOn')} ${r['last_checked']} · ${Uri.tryParse('${r['source'] ?? ''}')?.host ?? ''}'
              : (lang.ne ? 'अझै जाँच गरिएको छैन' : 'not yet verified'),
          style: T.meta,
        ),
      ]),
    );
  }
}
