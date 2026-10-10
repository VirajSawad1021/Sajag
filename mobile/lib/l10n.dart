// Every user-facing string, in Nepali and English. Nepali is the default.
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Lang extends ValueNotifier<String> {
  Lang() : super('ne');
  static const _key = 'sajag.lang.v1';
  bool get ne => value == 'ne';

  Future<void> load() async => value = (await SharedPreferences.getInstance()).getString(_key) ?? 'ne';

  void toggle() {
    value = ne ? 'en' : 'ne';
    SharedPreferences.getInstance().then((p) => p.setString(_key, value)); // remembered across launches
  }
}

final lang = Lang();

String tr(String key) => trIn(key, lang.value);

/// A string in a specific language, regardless of the app's current language (used for read-aloud).
String trIn(String key, String code) => (_s[key]?[code]) ?? (_s[key]?['en']) ?? key;

const _s = <String, Map<String, String>>{
  'tagline': {'ne': 'पैसा पठाउनुअघि,\nसजग।', 'en': 'Before you pay,\nstay alert.'},
  'heroSub': {
    'ne': 'बिक्रेताको च्याट, QR वा भ्वाइस नोट दिनुहोस्। Gemma ले पढ्छ, प्रमाणसहित चेतावनी देखाउँछ, र अर्को कदममा साथ दिन्छ।',
    'en': 'Share the seller\'s chat, QR or voice note. Gemma reads it, shows warning signs with evidence, and stays with you for the next step.',
  },
  'newCheck': {'ne': 'नयाँ जाँच', 'en': 'New check'},
  'emergency': {'ne': 'मैले OTP दिएँ / खाता ह्याक भयो', 'en': 'I shared my OTP / got hacked'},
  'emergencySub': {'ne': 'तुरुन्त के गर्ने', 'en': 'What to do right now'},
  'casebook': {'ne': 'तपाईंका केसहरू', 'en': 'Your cases'},
  'casebookEmpty': {
    'ne': 'तपाईंले जाँचेका कुरा यहाँ बस्छन् — फोनमै, कुनै खाता बिना।',
    'en': 'Everything you check lives here — on your phone, no account needed.',
  },
  'dueToday': {'ne': 'आज फलोअप गर्नुपर्ने', 'en': 'Follow up today'},
  'stageQ': {'ne': 'पैसा पठाइसक्नुभयो?', 'en': 'Have you paid already?'},
  'notYet': {'ne': 'अहिलेसम्म छैन', 'en': 'Not yet'},
  'paid': {'ne': 'पठाइसकें', 'en': 'Yes, I paid'},
  'addEvidence': {'ne': 'प्रमाण थप्नुहोस्', 'en': 'Add evidence'},
  'screenshot': {'ne': 'स्क्रिनसट', 'en': 'Screenshot'},
  'camera': {'ne': 'क्यामेरा', 'en': 'Camera'},
  'voiceFile': {'ne': 'भ्वाइस नोट', 'en': 'Voice note'},
  'record': {'ne': 'बोलेर भन्नुहोस्', 'en': 'Say it'},
  'stop': {'ne': 'रोक्नुहोस्', 'en': 'Stop'},
  'pasteHint': {'ne': 'वा म्यासेज / बैंक SMS यहाँ टाँस्नुहोस्', 'en': 'Or paste messages / a bank SMS here'},
  'samples': {'ne': 'नमुना', 'en': 'Samples'},
  'check': {'ne': 'जाँच गर्नुहोस्', 'en': 'Check it'},
  'needEvidence': {'ne': 'पहिले स्क्रिनसट, भ्वाइस नोट वा म्यासेज थप्नुहोस्।', 'en': 'Add a screenshot, voice note or message first.'},
  'privacyNote': {
    'ne': 'केस तपाईंको फोनमै बस्छ। जाँचका लागि मात्र Sajag सर्भर र Gemma (Google API) मा पठाइन्छ, सेभ गरिँदैन।',
    'en': 'Cases stay on your phone. Evidence is sent to the Sajag server and Gemma (Google API) only for the check, and is not stored there.',
  },
  'live_received': {'ne': 'प्रमाण प्राप्त भयो', 'en': 'Evidence received'},
  'live_qr': {'ne': 'QR पढियो — पैसा जाने व्यक्ति', 'en': 'QR decoded — money goes to'},
  'live_voice': {'ne': 'भ्वाइस नोट लेखियो', 'en': 'Voice note transcribed'},
  'live_reading': {'ne': 'Gemma 4 ले प्रमाण पढ्दैछ', 'en': 'Gemma 4 is reading your evidence'},
  'phase_transcribing': {'ne': 'स्क्रिनसटका म्यासेज पढ्दै', 'en': 'Reading the messages in your screenshots'},
  'phase_facts': {'ne': 'मूल्य, भुक्तानी र वाचा निकाल्दै', 'en': 'Pulling out prices, payment terms and promises'},
  'phase_timeline': {'ne': 'घटनाक्रम बनाउँदै', 'en': 'Building the timeline'},
  'phase_signals': {'ne': 'चेतावनीका संकेत जाँच्दै', 'en': 'Checking for warning signs'},
  'phase_deadlines': {'ne': 'फलोअप गर्नुपर्ने मिति खोज्दै', 'en': 'Finding dates to follow up on'},
  'live_read': {'ne': 'पढिसक्यो', 'en': 'Finished reading'},
  'live_signal': {'ne': 'प्रमाणसहित पुष्टि भयो', 'en': 'Verified against your evidence'},
  'live_xray': {'ne': 'स्क्रिनसटमा चिन्ह लगाइयो', 'en': 'Marked on your screenshot'},
  'liveTitle': {'ne': 'जाँच हुँदैछ', 'en': 'Checking'},
  'verifiedNote': {
    'ne': 'हरेक चेतावनीको उद्धरण तपाईंकै प्रमाणमा भेटिएपछि मात्र देखाइन्छ।',
    'en': 'A warning is shown only after its quote is found in your own evidence.',
  },
  'level_high': {'ne': 'धेरै सावधान', 'en': 'High caution'},
  'level_caution': {'ne': 'सावधान', 'en': 'Caution'},
  'level_low': {'ne': 'ठूलो संकेत भेटिएन', 'en': 'No major signs'},
  'level_insufficient': {'ne': 'जानकारी अपुग', 'en': 'Not enough information'},
  'levelBody_high': {'ne': 'गम्भीर चेतावनी भेटियो। पैसा वा जानकारी पठाउनुअघि रोकिनुहोस्।', 'en': 'Serious warning signs. Stop before sending money or information.'},
  'levelBody_caution': {'ne': 'केही चेतावनी भेटिए। पैसा पठाउनुअघि तलका कुरा जाँच्नुहोस्।', 'en': 'Some warning signs. Check the points below before paying.'},
  'levelBody_low': {'ne': 'स्पष्ट चेतावनी भेटिएन, तर यो सुरक्षित भन्ने प्रमाण होइन।', 'en': 'No clear warning signs — that is not proof it is safe.'},
  'levelBody_insufficient': {'ne': 'निर्णय गर्न पुग्ने जानकारी छैन। थप स्क्रिनसट थप्नुहोस्।', 'en': 'Not enough to judge. Add more screenshots.'},
  'paidLevel_high': {'ne': 'अहिले नै कदम चाल्नुहोस्', 'en': 'Act now'},
  'paidBody_high': {'ne': 'गम्भीर संकेत भेटियो। तुरुन्तै बैंक/वालेटलाई खबर गर्नुहोस् र प्रमाण सुरक्षित राख्नुहोस्।', 'en': 'Serious signs found. Tell your bank or wallet right away and keep all evidence.'},
  'xray': {'ne': 'स्क्याम एक्स-रे', 'en': 'Scam X-Ray'},
  'xrayHint': {'ne': 'चिन्ह लागेको म्यासेजमा थिच्नुहोस्', 'en': 'Tap a marked message'},
  'warnings': {'ne': 'चेतावनीका संकेत', 'en': 'Warning signs'},
  'noWarnings': {'ne': 'स्पष्ट चेतावनी भेटिएन। तैपनि तलका कदम हेर्नुहोस्।', 'en': 'No clear warning signs. Still look at the steps below.'},
  'notAlways': {'ne': 'सधैं ठगी हुँदैन', 'en': 'Not always a scam'},
  'unknowns': {'ne': 'थाहा नभएका कुरा', 'en': 'Still unknown'},
  'qrPays': {'ne': 'QR ले पैसा पठाउने ठाउँ', 'en': 'Who the QR actually pays'},
  'agent': {'ne': 'Sajag एजेन्ट', 'en': 'Sajag Agent'},
  'agentRun': {'ne': 'बिक्रेतालाई के सोध्ने? अनलाइन जाँच गर्नुहोस्', 'en': 'Check online and get questions to ask'},
  'agentRunFriend': {'ne': 'साँच्चै उहाँ नै हो? कसरी पुष्टि गर्ने', 'en': "How to check it's really them"},
  'agentWorking': {'ne': 'अनलाइन जाँच गर्दै र प्रश्न तयार गर्दै…', 'en': 'Checking online and writing questions…'},
  'scripts': {'ne': 'सुरक्षा स्क्रिप्ट', 'en': 'Suraksha Scripts'},
  'scriptsHelp': {'ne': 'कपी वा सेयर गरेर बिक्रेतालाई आफैं पठाउनुहोस्।', 'en': 'Copy or share these to the seller yourself.'},
  'copy': {'ne': 'कपी', 'en': 'Copy'},
  'copied': {'ne': 'कपी भयो', 'en': 'Copied'},
  'share': {'ne': 'सेयर', 'en': 'Share'},
  'timeline': {'ne': 'घटनाक्रम', 'en': 'Timeline'},
  'followUps': {'ne': 'फलोअप रिमाइन्डर', 'en': 'Follow-up reminders'},
  'reminderSet': {'ne': 'रिमाइन्डर राखियो', 'en': 'Reminder set'},
  'nextSteps': {'ne': 'अब के गर्ने?', 'en': 'What to do now'},
  'addReply': {'ne': 'जवाफ थप्नुहोस्', 'en': 'Seller replied'},
  'iPaid': {'ne': 'मैले पैसा तिरिसकें', 'en': 'I already paid'},
  'startRecovery': {'ne': 'रिकभरी सुरु गर्नुहोस्', 'en': 'Start recovery'},
  'warnFamily': {'ne': 'परिवारलाई सचेत गराउनुहोस्', 'en': 'Warn your family'},
  'recovery': {'ne': 'रिकभरी', 'en': 'Recovery'},
  'recoverySub': {'ne': 'छिटो गरिएको रिपोर्टले बैंक/वालेटलाई कदम चाल्ने सबैभन्दा राम्रो मौका दिन्छ।', 'en': 'Reports made soon after payment give your wallet the best chance to act.'},
  'stepsDone': {'ne': 'कदम पूरा', 'en': 'steps done'},
  'markDone': {'ne': 'भयो', 'en': 'Done'},
  'undo': {'ne': 'फिर्ता', 'en': 'Undo'},
  'call': {'ne': 'फोन', 'en': 'Call'},
  'email': {'ne': 'इमेल', 'en': 'Email'},
  'open': {'ne': 'खोल्नुहोस्', 'en': 'Open'},
  'checkedOn': {'ne': 'जाँचिएको', 'en': 'checked'},
  'petition': {'ne': 'साइबर ब्युरो निवेदन', 'en': 'Cyber Bureau application'},
  'petitionSub': {'ne': 'Gemma ले भर्छ, तपाईं जाँचेर सच्याउनुहुन्छ', 'en': 'Gemma fills it, you review and edit'},
  'yourStory': {'ne': 'के भयो? आफ्नै शब्दमा (नेपालीमा)', 'en': 'What happened? In your own words'},
  'fillWithGemma': {'ne': 'Gemma लाई भर्न लगाउनुहोस्', 'en': 'Let Gemma fill it'},
  'filling': {'ne': 'निवेदन भर्दै…', 'en': 'Filling the application…'},
  'yourDetails': {'ne': 'तपाईंको विवरण', 'en': 'Your details'},
  'name': {'ne': 'नाम थर', 'en': 'Full name'},
  'permAddr': {'ne': 'स्थायी ठेगाना', 'en': 'Permanent address'},
  'currAddr': {'ne': 'हालको ठेगाना', 'en': 'Current address'},
  'phone': {'ne': 'फोन', 'en': 'Phone'},
  'emailAddr': {'ne': 'इमेल', 'en': 'Email'},
  'makePdf': {'ne': 'PDF बनाउनुहोस्', 'en': 'Make the PDF'},
  'foundInEvidence': {'ne': 'प्रमाणमा भेटियो', 'en': 'found in evidence'},
  'checkThis': {'ne': 'प्रमाणमा भेटिएन — जाँच्नुहोस्', 'en': 'not found in evidence — check it'},
  'petitionHow': {
    'ne': 'छापेर सही गर्नुहोस्, नागरिकता/राष्ट्रिय परिचयपत्रको प्रतिलिपि जोड्नुहोस्, र नजिकको प्रहरी कार्यालय वा भोटाहिटीको साइबर ब्युरोमा बुझाउनुहोस्। जान नसके cyberbureau@nepalpolice.gov.np मा इमेल गर्न सकिन्छ।',
    'en': 'Print and sign it, attach a copy of your citizenship/national ID, and submit at your nearest police office or the Cyber Bureau in Bhotahiti. If you can\'t go, you can email it to cyberbureau@nepalpolice.gov.np.',
  },
  'friendCard': {'ne': 'साथी वा आफन्तले पैसा माग्यो?', 'en': 'A friend asked for money?'},
  'friendCardSub': {'ne': 'ह्याक भएको खाता त होइन? जाँच्नुहोस्', 'en': "Check it isn't a hacked account"},
  'friendHint': {
    'ne': 'साथी वा आफन्तको च्याटको स्क्रिनसट थप्नुहोस्। ह्याक भएका खाताबाट हतारमा पैसा वा कोड मागिन्छ। पठाउनुअघि सधैं पुरानो नम्बरमा फोन गर्नुहोस्।',
    'en': "Add a screenshot of the friend's or relative's chat. Hacked accounts urgently ask for money or codes. Always call their usual number before sending anything.",
  },
  'friendSample': {'ne': 'दिदीको खाताबाट पैसा माग', 'en': '"Didi" asks for money'},
  'hideDetails': {'ne': 'निजी विवरण लुकाउनुहोस्', 'en': 'Hide private details'},
  'hideHelp': {
    'ne': 'OTP, ब्यालेन्स, खाता नम्बर वा अनुहारमाथि औंलाले बाकस बनाउनुहोस्। ती ठाउँ तस्बिरमै कालो पारिन्छ र लुकाइएको प्रति मात्र पठाइन्छ। मूल तस्बिर तपाईंको ग्यालरीमै रहन्छ।',
    'en': 'Drag boxes over OTPs, balances, account numbers or faces. They are blacked out in the image itself and only the hidden copy is sent. Your original stays in your gallery.',
  },
  'hiddenCount': {'ne': 'ठाउँ लुकाइयो', 'en': 'areas hidden'},
  'useHidden': {'ne': 'यही प्रयोग गर्नुहोस्', 'en': 'Use this'},
  'readAloud': {'ne': 'सुनाउनुहोस्', 'en': 'Read aloud'},
  'stopReading': {'ne': 'रोक्नुहोस्', 'en': 'Stop'},
  'noNepaliVoice': {
    'ne': 'फोनमा नेपाली आवाज छैन, अंग्रेजीमा सुनाइयो। Settings → Google Speech Services → Install voice data → Nepali थप्नुहोस्।',
    'en': 'No Nepali voice on this phone. Add it in Settings → Google Speech Services → Install voice data → Nepali.',
  },
  'settings': {'ne': 'सेटिङ', 'en': 'Settings'},
  'serverUrl': {'ne': 'Sajag सर्भर ठेगाना', 'en': 'Sajag server address'},
  'testConnection': {'ne': 'जडान जाँच्नुहोस्', 'en': 'Test connection'},
  'connected': {'ne': 'जडान भयो', 'en': 'Connected'},
  'disclaimer': {'ne': 'यी चेतावनीका संकेत हुन्, ठगीको प्रमाण होइनन्। अन्तिम निर्णय तपाईंको।', 'en': 'These are warning signs, not proof of fraud. The decision is yours.'},
  'retry': {'ne': 'फेरि प्रयास', 'en': 'Try again'},
  'error': {'ne': 'केही मिलेन', 'en': 'Something went wrong'},
  'status_watching': {'ne': 'जाँचमा', 'en': 'Checking'},
  'status_paid': {'ne': 'डेलिभरी पर्खँदै', 'en': 'Awaiting delivery'},
  'status_recovery': {'ne': 'रिकभरी', 'en': 'Recovery'},
  'status_resolved': {'ne': 'समाधान', 'en': 'Resolved'},
  'markResolved': {'ne': 'समाधान भयो', 'en': 'Mark resolved'},
  'delete': {'ne': 'मेटाउनुहोस्', 'en': 'Delete'},
  'riskChanged': {'ne': 'जोखिम बदलियो', 'en': 'Risk changed'},
  'riskSame': {'ne': 'जवाफसहित फेरि जाँचियो — अझै', 'en': 'Re-checked with the reply — still'},
  'evidence': {'ne': 'प्रमाण', 'en': 'Evidence'},
  'readByGemma': {'ne': 'Gemma ले पढेको पाठ', 'en': 'Text read by Gemma'},
  'readByAsr': {'ne': 'भ्वाइस नोटबाट लेखिएको (speech-to-text)', 'en': 'Transcribed from the voice note (speech-to-text)'},
};
