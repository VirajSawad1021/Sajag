// "I shared my OTP / my account was hacked" — the minutes that matter. Steps follow eSewa's and Khalti's own
// published guidance and NRB's notice; the eSewa insurance window is quoted from eSewa's blog with its limits.
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n.dart';
import '../models.dart';
import '../store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/contacts.dart';
import '../widgets/speak_button.dart';
import 'new_check_screen.dart';

class EmergencyScreen extends StatelessWidget {
  const EmergencyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ne = lang.ne;
    Widget step(int n, String title, String body, {Widget? extra}) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: RaisedCard(
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: C.high, shape: BoxShape.circle),
                child: Text('$n', style: T.pill.copyWith(color: Colors.white)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: T.h3),
                  const SizedBox(height: 4),
                  Text(body, style: T.small),
                  if (extra != null) ...[const SizedBox(height: 10), extra],
                ]),
              ),
            ]),
          ),
        );

    return Scaffold(
      appBar: AppBar(title: Text(tr('emergency'))),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 40), children: [
        Module(
          color: C.highBg,
          borderColor: C.highBg,
          child: Text(
            ne
                ? 'शान्त रहनुहोस्। तलका कदम क्रमैसँग, अहिले नै गर्नुहोस्। वालेट/बैंकले कहिल्यै OTP, PIN वा पासवर्ड माग्दैन — माग्ने जो कोही पनि ठग हो, चाहे फोनमा जुनसुकै नाम/नम्बर देखियोस्।'
                : 'Stay calm and do these steps now, in order. Wallets and banks never ask for your OTP, PIN or password — anyone who does is a scammer, whatever name or number shows on your phone.',
            style: T.small.copyWith(color: C.high, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 12),
        SpeakButton(
          id: 'emergency',
          primary: true,
          text: () => (
            ne: 'शान्त रहनुहोस्। पहिलो, अहिले नै आफ्नो वालेट वा बैंकलाई आधिकारिक नम्बरमा फोन गरेर खाता रोक्न भन्नुहोस्। '
                'दोस्रो, पिन र पासवर्ड बदल्नुहोस्। तेस्रो, अब कसैलाई पनि कोड नदिनुहोस्, फोन आए काट्नुहोस्। '
                'ई-सेवा प्रयोग गर्नुहुन्छ भने अठचालीस घण्टाभित्र बीमा दाबी गर्नुहोस्। '
                'अन्तमा, साइबर ब्युरोमा उजुरी गर्नुहोस्। वालेट वा बैंकले कहिल्यै ओटीपी माग्दैन।',
            en: 'Stay calm. First, call your wallet or bank now on its official number and ask them to block the account. '
                'Second, change your PIN and password. Third, share no more codes and hang up if they call again. '
                'If you use eSewa, make the insurance claim within 48 hours. Finally, report it to the Cyber Bureau. '
                'Wallets and banks never ask for your OTP.',
          ),
        ),
        const SizedBox(height: 16),
        step(1, ne ? 'वालेट/बैंकलाई अहिले नै फोन गर्नुहोस्' : 'Call your wallet or bank now',
            ne ? 'खाता/सेवा रोक्न भन्नुहोस्। आधिकारिक नम्बर मात्र प्रयोग गर्नुहोस्।' : 'Ask them to block the account or service. Use official numbers only.',
            extra: const OfficialContacts(ids: ['esewa', 'khalti', 'bank_or_wallet'])),
        step(2, ne ? 'PIN र पासवर्ड बदल्नुहोस्' : 'Change your PIN and password',
            ne ? 'वालेट, बैंक एप र जोडिएको इमेल/Facebook को पासवर्ड बदल्नुहोस्; अरू डिभाइसबाट लगआउट गर्नुहोस्।'
                : 'Change your wallet, bank app and linked email/Facebook passwords, and log out of other devices.'),
        step(3, ne ? 'अब कुनै कोड नदिनुहोस्' : 'Share no more codes',
            ne ? 'फेरि फोन आए काट्नुहोस्। "रिफन्ड" वा "भेरिफाई" भन्दै पैसा/कोड माग्नु पनि ठगीकै हिस्सा हो।'
                : 'Hang up if they call again. Asking for money or codes to "refund" or "verify" is part of the scam.'),
        step(4, ne ? 'ई-सेवा प्रयोगकर्ता: बीमा दाबी ४८ घण्टाभित्र' : 'eSewa users: insurance claim within 48 hours',
            ne
                ? 'ई-सेवाको वालेट बीमामा घटनाको ४८ घण्टाभित्र ई-सेवा/हिमालयन एभरेष्ट इन्स्योरेन्सलाई दाबी सूचना दिनुपर्छ र प्रहरीमा उजुरी चाहिन्छ। प्रति घटना बढीमा रु. २०,०००; सामाजिक सञ्जाल ह्याक भएर भएको ठगी समेटिँदैन। पूरा सर्त ई-सेवासँग पुष्टि गर्नुहोस्।'
                : 'eSewa\'s wallet insurance needs a claim notice to eSewa/Himalayan Everest Insurance within 48 hours, plus a police complaint. Max Rs 20,000 per event; fraud through hacked social media accounts is excluded. Confirm the full terms with eSewa.',
            extra: Pill(ne ? 'स्रोत: ई-सेवा ब्लग' : 'Source: eSewa blog', primary: false, icon: Icons.open_in_new_rounded,
                onTap: () => launchUrl(Uri.parse('https://blog.esewa.com.np/?p=13295'), mode: LaunchMode.externalApplication))),
        step(5, ne ? 'साइबर ब्युरोमा उजुरी' : 'Report to the Cyber Bureau',
            ne ? 'केस खोल्नुहोस् — Sajag ले प्रमाण मिलाउँछ र निवेदन भर्न मद्दत गर्छ।' : 'Open a case — Sajag organises the evidence and helps fill the application.',
            extra: const OfficialContacts(ids: ['cyber_bureau'])),
        const SizedBox(height: 6),
        Pill(ne ? 'यसको केस खोल्नुहोस्' : 'Open a case for this', big: true, icon: Icons.add_rounded, onTap: () async {
          final c = SajagCase(stage: 'after_payment', status: CaseStatus.recovery, title: ne ? 'OTP / खाता ह्याक' : 'OTP / hacked account');
          await store.save(c);
          if (context.mounted) {
            Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => NewCheckScreen(caseId: c.id)));
          }
        }),
      ]),
    );
  }
}
