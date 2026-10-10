import type { Lang, RiskLevel } from "./types";

const strings = {
  tagline: { ne: "पैसा पठाउनुअघि, सजग।", en: "Before you send money, stay alert." },
  intro: {
    ne: "बिक्रेताको च्याटको स्क्रिनसट, विज्ञापन, भुक्तानी QR वा भ्वाइस नोट राख्नुहोस्। Sajag ले के जाँच्नुपर्छ भनेर प्रमाणसहित देखाउँछ।",
    en: "Add screenshots of the seller's chat, the listing, the payment QR or a voice note. Sajag shows what to check, with the evidence.",
  },
  stageQuestion: { ne: "तपाईंले पैसा पठाइसक्नुभयो?", en: "Have you already paid?" },
  stageBefore: { ne: "अहिलेसम्म छैन", en: "Not yet" },
  stageAfter: { ne: "पठाइसकें", en: "Yes, I paid" },
  addScreenshots: { ne: "स्क्रिनसट / QR थप्नुहोस्", en: "Add screenshots / QR" },
  voiceFormats: { ne: "भ्वाइस नोट (m4a, ogg, mp3)", en: "voice notes (m4a, ogg, mp3)" },
  recordVoice: { ne: "🎙 बोलेर बताउनुहोस्", en: "🎙 Explain by voice" },
  stopRecording: { ne: "रोक्नुहोस्", en: "Stop" },
  micDenied: { ne: "माइक्रोफोन प्रयोग गर्न अनुमति मिलेन।", en: "Microphone permission was not granted." },
  voiceTranscript: {
    ne: "भ्वाइस नोटबाट लेखिएको पाठ (speech-to-text) — गल्ती हुन सक्छ",
    en: "Voice note transcribed by speech-to-text — may contain mistakes",
  },
  agentTitle: { ne: "Sajag एजेन्ट", en: "Sajag Agent" },
  agentWorking: {
    ne: "एजेन्टले अनलाइन जाँच गर्दै र बिक्रेतालाई सोध्ने प्रश्न तयार गर्दैछ…",
    en: "The agent is checking online and preparing questions for the seller…",
  },
  agentSources: { ne: "अनलाइन जाँचका स्रोतहरू", en: "Sources from the web checks" },
  scriptsTitle: { ne: "सुरक्षा स्क्रिप्ट", en: "Suraksha Scripts" },
  scriptsHelp: {
    ne: "यी म्यासेज कपी गरेर बिक्रेतालाई आफैं पठाउनुहोस्। Sajag ले कसैलाई केही पठाउँदैन।",
    en: "Copy these and send them to the seller yourself. Sajag never messages anyone.",
  },
  whatChanges: { ne: "जोखिम कसरी बदलिन्छ", en: "What changes the risk" },
  addReply: { ne: "बिक्रेताको जवाफ थपेर फेरि जाँच्नुहोस्", en: "Add the seller's reply and re-check" },
  replyHint: {
    ne: "बिक्रेताको जवाफको स्क्रिनसट वा भ्वाइस नोट थप्नुहोस्। अघिल्लो प्रमाण पनि सँगै जाँचिन्छ।",
    en: "Add a screenshot or voice note of the seller's reply. Your earlier evidence is checked again with it.",
  },
  riskChanged: { ne: "जोखिम बदलियो", en: "Risk changed" },
  riskSame: { ne: "बिक्रेताको जवाफसहित फेरि जाँचियो — अझै", en: "Re-checked with the seller's reply — still" },
  trySample: { ne: "नमुना:", en: "Try a sample:" },
  pasteLabel:{ ne: "वा म्यासेज यहाँ टाँस्नुहोस्", en: "Or paste the messages here" },
  pastePlaceholder: { ne: "Seller: COD milcha...\nSeller: Advance pathaunus...", en: "Seller: COD milcha...\nSeller: Advance pathaunus..." },
  check: { ne: "जाँच गर्नुहोस्", en: "Check" },
  checking: { ne: "जाँच हुँदैछ…", en: "Checking…" },
  checkingHint: {
    ne: "Gemma ले तपाईंको प्रमाण पढ्दैछ। सामान्यतया १५–४० सेकेन्ड लाग्छ।",
    en: "Gemma is reading your evidence. This usually takes 15–40 seconds.",
  },
  privacy: {
    ne: "तपाईंका फाइल जाँचका लागि सर्भरमा पठाइन्छ र सेभ गरिँदैन। सकेसम्म OTP, पासवर्ड जस्ता कुरा लुकाएर मात्र राख्नुहोस्।",
    en: "Your files are sent to the server for this check and are not stored. Hide OTPs, passwords and similar details where you can.",
  },
  disclaimer: {
    ne: "यी चेतावनीका संकेत हुन्, ठगी भएको प्रमाण होइनन्। अन्तिम निर्णय तपाईंकै हो।",
    en: "These are warning signs, not proof of fraud. The final decision is yours.",
  },
  signals: { ne: "चेतावनीका संकेत", en: "Warning signs" },
  noSignals: { ne: "कुनै स्पष्ट चेतावनी संकेत भेटिएन। तैपनि तलका कुरा जाँच्नुहोस्।", en: "No clear warning signs found. Still check the steps below." },
  unverified: { ne: "पुष्टि हुन नसकेका संकेत", en: "Unverified signs" },
  unverifiedHelp: {
    ne: "यी उद्धरण तपाईंको प्रमाणमा ठ्याक्कै भेटिएनन्, त्यसैले नतिजामा गनिएका छैनन्। आफैं जाँच्नुहोस्।",
    en: "These quotes could not be found exactly in your evidence, so they don't count towards the result. Check them yourself.",
  },
  evidence: { ne: "प्रमाण", en: "Evidence" },
  whyMatters: { ne: "किन ध्यान दिने?", en: "Why it matters" },
  notAlways: { ne: "सधैं ठगी हुँदैन", en: "Not always a scam" },
  unknowns: { ne: "थाहा नभएका कुरा", en: "Still unknown" },
  qrTitle: { ne: "QR ले पैसा कसलाई पठाउँछ", en: "Who the QR actually pays" },
  qrPayee: { ne: "प्राप्तकर्ता", en: "Payee" },
  qrChecksumBad: { ne: "QR को checksum मिलेन — QR बिग्रिएको वा परिवर्तन गरिएको हुन सक्छ।", en: "QR checksum mismatch — it may be damaged or edited." },
  timeline: { ne: "घटनाक्रम", en: "Timeline" },
  nextSteps: { ne: "अब के गर्ने?", en: "What to do now" },
  sources: { ne: "तपाईंको प्रमाण", en: "Your evidence" },
  readByModel: { ne: "Gemma ले पढेको पाठ — गल्ती हुन सक्छ", en: "Text read by Gemma — may contain mistakes" },
  newCheck: { ne: "नयाँ जाँच", en: "New check" },
  downloadReport: { ne: "रिपोर्ट डाउनलोड", en: "Download report" },
  prepareComplaint: { ne: "उजुरीको मस्यौदा बनाउनुहोस्", en: "Prepare a complaint draft" },
  complaintTitle: { ne: "उजुरीको मस्यौदा", en: "Complaint draft" },
  complaintHelp: {
    ne: "Sajag ले उजुरी आफैं पठाउँदैन। मस्यौदा बनाउँछ, तपाईं सच्याएर आफैं पेस गर्नुहोस्।",
    en: "Sajag never submits anything. It prepares a draft for you to edit and submit yourself.",
  },
  recipient: { ne: "कसलाई?", en: "Send to" },
  name: { ne: "नाम", en: "Name" },
  address: { ne: "ठेगाना", en: "Address" },
  phone: { ne: "फोन", en: "Phone" },
  bankName: { ne: "बैंक / वालेटको नाम", en: "Bank / wallet name" },
  amountPaid: { ne: "तिरेको रकम (रु.)", en: "Amount paid (Rs.)" },
  paidOn: { ne: "भुक्तानी मिति", en: "Payment date" },
  txnRef: { ne: "कारोबार नम्बर", en: "Transaction ID" },
  story: { ne: "के भयो? आफ्नै शब्दमा", en: "What happened? In your own words (Nepali)" },
  makeDraft: { ne: "मस्यौदा बनाउनुहोस्", en: "Make draft" },
  copy: { ne: "कपी", en: "Copy" },
  copied: { ne: "कपी भयो", en: "Copied" },
  download: { ne: "डाउनलोड", en: "Download" },
  back: { ne: "पछाडि", en: "Back" },
  officialLinks: { ne: "आधिकारिक ठाउँ", en: "Official places" },
  notVerifiedLink: { ne: "लिंक अझै जाँच गरिएको छैन", en: "link not yet verified" },
  checkedOn: { ne: "जाँचिएको मिति", en: "checked" },
  offlineEngine: {
    ne: "Gemma बिना अफलाइन शब्द-जाँच मात्र भयो — स्क्रिनसट पढिएन।",
    en: "Offline keyword check only (no Gemma) — screenshots were not read.",
  },
} satisfies Record<string, Record<Lang, string>>;

export type StringKey = keyof typeof strings;
export const t = (key: StringKey, lang: Lang): string => strings[key][lang];

export const levelText: Record<RiskLevel, Record<Lang, { title: string; body: string }>> = {
  high: {
    ne: { title: "धेरै सावधान", body: "गम्भीर चेतावनी संकेत भेटियो। पैसा वा जानकारी पठाउनुअघि रोकिनुहोस्।" },
    en: { title: "High caution", body: "Serious warning signs found. Stop before sending money or information." },
  },
  caution: {
    ne: { title: "सावधान", body: "केही चेतावनी संकेत भेटिए। पैसा पठाउनुअघि तलका कुरा जाँच्नुहोस्।" },
    en: { title: "Caution", body: "Some warning signs found. Check the points below before paying." },
  },
  low: {
    ne: { title: "ठूलो संकेत भेटिएन", body: "स्पष्ट चेतावनी भेटिएन, तर यसको अर्थ सुरक्षित भन्ने होइन।" },
    en: { title: "No major signs", body: "No clear warning signs, but that does not mean it is safe." },
  },
  insufficient: {
    ne: { title: "जानकारी अपुग", body: "निर्णय गर्न पर्याप्त जानकारी छैन। थप स्क्रिनसट राख्नुहोस्।" },
    en: { title: "Not enough information", body: "Not enough to judge. Add more screenshots." },
  },
};

// Banner wording once the user says they have already paid: "stop before paying" no longer helps.
export const afterPaymentText: Partial<Record<RiskLevel, Record<Lang, { title: string; body: string }>>> = {
  high: {
    ne: { title: "अहिले नै कदम चाल्नुहोस्", body: "गम्भीर संकेत भेटियो। तुरुन्तै बैंक/वालेटलाई सम्पर्क गर्नुहोस् र प्रमाण सुरक्षित राख्नुहोस्।" },
    en: { title: "Act now", body: "Serious warning signs found. Contact your bank or wallet right away and keep all evidence." },
  },
  caution: {
    ne: { title: "सावधान", body: "केही चेतावनी संकेत भेटिए। प्रमाण सुरक्षित राख्नुहोस् र तलका कदम हेर्नुहोस्।" },
    en: { title: "Caution", body: "Some warning signs found. Keep your evidence and follow the steps below." },
  },
};
