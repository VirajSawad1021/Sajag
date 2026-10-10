# Research notes (2026-10-10)

What we checked, where it came from, and what it changed in Sajag. Official sources were read directly on the
organisation's website; news and blog sources are marked as such. Re-check before the demo — procedures change.

## Official procedures (used in the app)

| Topic | Finding | Source | Used in |
|---|---|---|---|
| Cyber Bureau complaints | **No online form.** Download the category application (there is one for *Online Financial Fraud*, updated 2083-06-14), fill it typed or handwritten in Nepali or English, attach a copy of citizenship / national ID / passport and the URLs + clear screenshots, and submit at the nearest district or ward police office or the Cyber Bureau in Bhotahiti. If you can't go in person, email everything to cyberbureau@nepalpolice.gov.np. | [cyberbureau.nepalpolice.gov.np/report-cyber-crime](https://cyberbureau.nepalpolice.gov.np/report-cyber-crime/) | Petition agent + PDF, recovery step 5 |
| Cyber Bureau contacts | 9851286770, 01-5319044, cyberbureau@nepalpolice.gov.np | [Cyber Bureau homepage](https://cyberbureau.nepalpolice.gov.np/) | `data/resources.yaml` |
| NRB guidance on e-payment fraud | Inform the bank/provider immediately, stop the service, complain to them first; if unresolved, use gunaso.nrb.org.np. **No deadline in days is stated** — the app does not invent one. | [NRB notice, Aug 2026](https://www.nrb.org.np/2026/08/%E0%A4%B5%E0%A4%BF%E0%A4%A6%E0%A5%8D%E0%A4%AF%E0%A5%81%E0%A4%A4%E0%A5%80%E0%A4%AF-%E0%A4%AD%E0%A5%81%E0%A4%95%E0%A5%8D%E0%A4%A4%E0%A4%BE%E0%A4%A8%E0%A5%80%E0%A4%AE%E0%A4%BE-%E0%A4%A0%E0%A4%97%E0%A5%80/) | Recovery steps 1 and 6 |
| eSewa support | Toll-free 1660-01-02121 / 1810-21-02121, csd@esewa.com.np; links to NRB's grievance portal | [esewa.com.np](https://esewa.com.np/) | Contacts |
| Khalti support | Toll-free 16600158888 (NTC), 01-5970017, support@khalti.com, grievance@khalti.com, dispute policy page | [khalti.com](https://khalti.com/) | Contacts |
| eSewa wallet insurance | Claim notice to eSewa / Himalayan Everest Insurance **within 48 hours**, police complaint required, max Rs 20,000 per event, fraud via hacked social-media accounts excluded | [eSewa blog](https://blog.esewa.com.np/?p=13295) (official blog) | Emergency screen step 4 |
| eSewa on OTPs | eSewa never asks for password/OTP; scammers can spoof eSewa's caller ID | [eSewa blog](https://blog.esewa.com.np/?p=7917) | Emergency screen, OTP pattern |

## The problem space (news reporting — figures disagree, use ranges)

- Online fraud complaints to the Cyber Bureau are rising year on year; reports give roughly 4,000–7,700 fraud
  complaints per year in recent fiscal years, with **financial fraud the largest category**, then fake accounts,
  harassment and hacked accounts. ([myRepublica](https://myrepublica.nagariknetwork.com/news/financial-fraud-fake-accounts-dominate-nepals-cybercrime-complaints-73-57.html),
  [Rising Nepal](https://risingnepaldaily.com/news/84495), [Ratopati](https://english.ratopati.com/story/69286/the-scope-of-online-fraud-is-increasing-16-ways-people-are-being-cheated))
- Police describe 16 common methods, including fake bank/wallet "KYC update" calls asking for OTPs, phishing
  links, hacked or fake Facebook IDs, parcel-from-abroad and lottery scams. The Cyber Bureau homepage currently
  highlights arrests for exactly these KYC/eSewa-staff scams. ([Onlinekhabar](https://english.onlinekhabar.com/4-arrested-for-otp-fraud-in-bank-kyc-scam.html))
- Telegram has been blocked by the Nepal Telecommunications Authority since July 2025; no report of the block
  being lifted was found, and api.telegram.org is unreachable from this network. **Don't demo the Telegram bot.**
  ([WION](https://www.wionews.com/world/nepal-orders-telecom-providers-to-immediately-block-telegram-here-s-why-1752857624225/amp), [Access Now](https://www.accessnow.org/press-release/keepiton-nepals-telegram-ban-is-a-dangerous-escalation-of-digital-censorship/))

## What this changed in the product

1. **Recovery mode** follows NRB's order of steps and links only verified contacts.
2. **"I shared my OTP / got hacked" emergency screen** — the most common tactic needed its own fast path,
   including eSewa's 48-hour insurance window, which people miss.
3. **Petition agent**: since the Bureau has no online form, the useful help is filling *its own application*
   correctly (formal Nepali, B.S. date, numbered annexes) so the person can print/sign or email it.
4. **Warn your family** share — fake-staff and hacked-account scams spread through families; one tap sends a
   plain Nepali warning.

## Ideas we did not build (and why)

| Idea | Why not (yet) |
|---|---|
| Read OTP / bank SMS automatically | Needs Android SMS / notification-listener permissions — exactly what banking malware asks for; Play Store restricts it. Users forward the SMS instead. |
| Screenshot a Messenger inbox automatically | Requires controlling the phone or automating Messenger (against Meta's terms) — a security red flag. |
| Verify foreign-employment agencies | Could not find an official public licence lookup from the Department of Foreign Employment. Revisit if one exists. |
| Community "reported account" warnings | Needs real eSewa/Khalti/Fonepay QR samples to confirm a stable account ID is inside, plus abuse safeguards. |
| Download the Bureau's PDF form into the repo | Waiting for the team's OK; the app's application follows the documented requirements in the meantime. |
