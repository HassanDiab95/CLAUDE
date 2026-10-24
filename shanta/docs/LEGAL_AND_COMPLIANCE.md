# Shanta — Legal & Compliance Guide (Egypt + Middle East + International)

> **Important:** This is a structured research summary to help you plan. It is **not legal advice**.
> Laws, limits and fees in this area change often (several changed in 2025–2026). Before launch,
> get a written opinion from an Egyptian law firm with customs, fintech and data-protection practice,
> and a licensed customs broker. Items marked **[verify]** could not be confirmed from an official source.

---

## 1. Short answer: is the idea legal?

**Yes, it can be run legally, but only in a specific shape.** No Egyptian or GCC law forbids a
passenger from carrying goods in their own baggage, and no law forbids a website that introduces
travelers to people. The legal risk comes from five places:

| # | Risk | Why it matters | How Shanta handles it |
|---|------|----------------|------------------------|
| 1 | **Customs** | Duty-free allowances cover *personal* effects. Goods carried for other people, in commercial quantities or by "frequent" carriers can lose the exemption and be treated as smuggling if not declared. | Value warnings per destination, a weight cap, a "declare it" rule, and the "Buy it for me" mode. |
| 2 | **Postal / courier licensing** | In Egypt the **National Postal Authority (NPA)** licenses private courier companies (DHL, Aramex, UPS and others hold licences). A platform that *itself* collects, stores or delivers parcels may be treated as an unlicensed courier. | Shanta never touches goods. It is a marketplace: the traveler carries the item as their own accompanied baggage. |
| 3 | **Drugs and contraband** | Egypt (Law 182/1960) and the GCC punish drug trafficking extremely severely, up to the death penalty. Travelers have been jailed for carrying "a parcel for a friend". | Closed packages are banned. The traveler must open and inspect every item in the app before departure, and ID verification is mandatory. |
| 4 | **Payments** | Holding users' money is a regulated payment service in Egypt. | Escrow runs through a **CBE-licensed payment provider**. Shanta never holds the funds. |
| 5 | **Personal data** | Shanta collects IDs, selfies, phone numbers and travel dates. | Compliance with Egypt PDPL 151/2020 and its 2025 Executive Regulations (see §3.4). |

**The safest model, which Shanta defaults to, is "Buy it for me":** the traveler buys a *new* item
from a shop in the origin country, keeps the invoice in their own name, and brings it as their own
purchase. The recipient reimburses the price plus a reward through escrow. This avoids carrying
unknown items for strangers. It also keeps the transaction closer to a personal purchase than a
courier service.

---

## 2. Rules for the traveler and the item

### 2.1 Customs: Egypt (destination)

- **Law:** Customs Law **No. 207 of 2020** (in force 12 Nov 2020). It replaced the 1963 Customs Law and
  absorbed the 1986 Customs Exemptions Law, and it keeps an exemption for travelers' personal baggage.
  Executive Regulations: Minister of Finance Decree **430/2021**.
- **Personal-use test:** the exemption covers personal effects in **non-commercial quantities**. Several
  identical new items, or goods clearly for resale, are dutiable and must be declared. The exact value
  threshold in the regulations is **[verify]**, so Shanta uses a conservative ~USD 500 warning level.
- **Mobile phones (major change):** from **21 January 2026, 12:00**, Egypt **ended the one-phone
  duty-free exemption** for phones carried by passengers. Taxes are paid through the **"Telephony" app**,
  a bank or an e-wallet, with a 90-day grace period after activation. Phones of Egyptians living abroad
  and of tourists keep a temporary 90-day exemption. → Shanta flags `electronics` with this warning.
- **Currency:** Egypt requires declaring foreign currency above **USD 10,000** (or equivalent) **[verify current EGP limit]**.
  Cash is **prohibited** on Shanta anyway.

### 2.2 Customs: Saudi Arabia and the GCC

- **GCC Common Customs Law, Art. 103:** personal luggage and gifts are duty-free only if
  **non-commercial**, worth **≤ 3,000 SAR** (UAE: AED 3,000), and the passenger is **not a frequent
  traveler through that customs office or a merchant** in those goods. That last condition matters for
  travelers who use Shanta often.
- **Cash and gold declaration (Saudi Arabia):** the threshold was **lowered from SAR 60,000 to SAR 40,000**
  (reported mid-2026). It covers cash, gold, jewelry, precious metals and gemstones, on entry and exit.
  Shanta bans precious goods and cash entirely.
- Keep receipts. ZATCA may ask for passport/ID and purchase invoices.

### 2.3 Aviation safety (international)

- **ICAO Annex 17 / airport security:** airlines and security staff ask "Has anyone given you anything to
  carry?". The traveler must be able to answer honestly, which is why Shanta requires inspecting the item open.
- **IATA Dangerous Goods Regulations:** lithium batteries and power banks go in **cabin baggage only**.
  No flammables, aerosols beyond limits, or gas canisters.
- **Airline conditions of carriage:** baggage is for the passenger's own belongings. Most airlines do not
  police this, but the traveler is responsible for anything in the bag. Excess weight is the traveler's cost.
- **Montreal Convention 1999** caps the airline's liability for lost or damaged baggage
  (≈1,519 SDR **[verify current figure]**). It does not cover the private deal between sender and traveler,
  so Shanta's terms and insurance must cover that.

### 2.4 Items banned on Shanta (enforced in code: `server/src/rules.js`)

Drugs and controlled medicines · weapons and replicas · explosives and flammables · cash and payment
instruments · gold, jewelry and gemstones · counterfeit goods · other people's passports or IDs ·
animals, plants and seeds · tobacco and alcohol · **any sealed package that cannot be inspected**.

**Allowed with warnings:** medicine (original box + prescription in the patient's name), electronics
(duty, Egypt phone tax), batteries (cabin only), sealed shelf-stable food, cosmetics (liquids rules).

---

## 3. Rules for the company (Egypt)

### 3.1 Company set-up
- Incorporate through **GAFI** (General Authority for Investment & Free Zones). The Investor Service
  Centre offers online incorporation.
- Typical form: **LLC**, or a **One-Person Company (OPC)** if you are the sole founder. You then get a
  commercial register extract, a **tax card**, and **VAT registration** (mandatory above EGP 500,000
  annual turnover, and advisable from day one for a platform).
- Activity description: *"operating an electronic platform for connecting users / e-marketing services"*.
  **Avoid** "shipping", "courier" or "freight" in the activity, because those trigger NPA / transport licensing.
- If you raise foreign venture capital, many Egyptian startups use a holding company abroad (ADGM/DIFC in
  the UAE, or Delaware) with an Egyptian operating subsidiary.
- Register the **trademark** "Shanta / شنطة" with Egypt's Trademark Office, and in KSA/UAE before expanding.

### 3.2 Courier / postal licensing (NPA)
- The **National Postal Authority** licenses private postal and express-courier operators. In Egypt,
  collecting and delivering mail and parcels for others is a licensed activity.
- **Recommendation:** before launch, request a **written opinion from the NPA, or from your lawyer after
  consulting the NPA**, confirming that a pure matching platform (no pickup, no storage, no delivery by
  the company or its staff) does not need a postal licence. If the NPA disagrees, partner with a licensed
  courier for the last-mile leg. **[verify — the text of the current postal law and its licensing rules was not confirmed]**

### 3.3 Payments and escrow
- **Central Bank and Banking System Law No. 194 of 2020**, plus the CBE's **Payment Service Provider
  Regulations (in force 17 June 2025)**. Issuing, receiving or holding payments for others requires a CBE
  licence.
- **Do not hold user money in the company's bank account.** Integrate a licensed provider that supports
  marketplace split payments or holds (e.g. Paymob, Fawry, Geidea, Kashier in Egypt; Tap, HyperPay,
  Checkout.com in the GCC), and confirm each provider's current licence.
- Fintech Law **No. 5 of 2022** (FRA) applies only if you add non-bank financial products such as
  insurance or lending.

### 3.4 Personal data
- **Personal Data Protection Law No. 151 of 2020.** Its **Executive Regulations** were issued by Ministerial
  Decree **No. 816 of 2025 (1 November 2025)**, starting a **one-year compliance grace period that ends
  around November 2026, i.e. now**.
- What applies to Shanta:
  - **Licence/permit** from the **Personal Data Protection Centre (PDPC)** to process data electronically.
  - **Explicit consent** and a clear Arabic + English privacy notice.
  - Appoint a **Data Protection Officer**.
  - Breach notification to the PDPC.
  - Rules for **cross-border transfers**: cloud servers outside Egypt and GCC users' data.
  - Extra care for **sensitive data**, including biometric selfies used for KYC.
  - Rules for **children's data**. Shanta is 18+ only.

### 3.5 Other Egyptian laws to cover in your Terms
- **Consumer Protection Law No. 181 of 2018:** platform disclosures, refunds and complaint handling.
- **E-Signature Law No. 15 of 2004:** validity of click-to-accept terms and electronic records.
- **Anti-Cybercrime Law No. 175 of 2018:** content moderation, data security, and log retention for authorities.
- **Anti-Money-Laundering Law No. 80 of 2002:** the "buy it for me" flow moves money across borders, so
  apply KYC, per-user limits and monitoring of unusual patterns. Your payment provider will require this too.
- **Tax:** corporate income tax (22.5%), VAT (14%) on Shanta's commission, and the ETA **e-invoice / e-receipt**
  systems. Travelers who earn regularly may have their own income-tax obligations; say so in the Terms.

### 3.6 App stores
- Apple and Google require a public privacy policy, **in-app account deletion**, a way to report users,
  and a contact address. Payments for physical goods and services may use your own payment provider.
  Apple/Google in-app purchase is not required for this kind of marketplace.

---

## 4. User eligibility (implemented as product rules)

| Requirement | Traveler | Sender / recipient |
|---|---|---|
| Age 18+ | ✔ | ✔ |
| Verified ID (national ID / passport) + selfie (eKYC) | ✔ (required to book) | ✔ (required to book) |
| Accept Terms + prohibited-items policy | ✔ (at sign-up) | ✔ (at sign-up) |
| Confirmed ticket (booking reference / e-ticket upload) | ✔ (recommended before first payout) | – |
| Not on sanctions / watch lists (screened by KYC provider) | ✔ | ✔ |
| Inspect item open and confirm in app | ✔ (enforced) | Must show item open |
| Give the 6-digit delivery code only on receipt | – | ✔ (enforced) |
| Declare goods above allowance at customs | ✔ (responsibility in Terms) | Pays any duty (in Terms) |

---

## 5. Must-have clauses in the Terms of Service
1. Shanta is a **technology marketplace**, not a carrier, courier, freight forwarder or customs broker.
2. The **traveler is the owner/declarant** of the goods at customs and may refuse any item at any time.
3. The sender guarantees the item is lawful, matches its description, and indemnifies the traveler.
4. **Who pays duties and taxes**: the recipient, reimbursed through the app.
5. Escrow, cancellation, no-show and refund rules, plus a **dispute process** with evidence (photos at inspection and at delivery).
6. Liability cap and optional **goods-in-transit insurance** through a licensed insurer.
7. Account suspension for prohibited items, and cooperation with authorities.
8. Governing law: Egypt (Cairo Economic Courts), with mandatory local-law carve-outs for GCC users.

---

## 6. Sources
- PwC – [Egypt: the new Customs Law No. 207/2020](https://www.pwc.com/m1/en/tax/documents/2020/egypt-the-new-customs-law-no-207-2020.pdf) · [Customs Regulations, Decree 430/2021](https://www.pwc.com/m1/en/tax/documents/2021/egypt-new-customs-regulations-minister-of-finance-decree-no430-2021.pdf)
- EY – [Egypt updates its customs laws](https://globaltaxnews.ey.com/news/2020-6527-egypt-updates-its-customs-laws) · [Law 207 of 2020 text (Andersen)](https://eg.andersen.com/wp-content/uploads/2025/09/Law-207-of-2020.pdf)
- NTRA – [End of exceptional exemption on passenger-carried phones (21 Jan 2026)](https://www.tra.gov.eg/en/?p=10745) · [Ahram Online](https://english.ahram.org.eg/NewsContentMulti/560808/Multimedia.aspx)
- ZATCA – [Passenger luggage exemption (Art. 103)](https://zatca.gov.sa/en/RulesRegulations/Taxes/Pages/customs-individual/Travel-pages/luggage.aspx) · [Airport customs guide](https://eservices.zatca.gov.sa/sites/sc/en/CustomsGuideNew/CustomsGuideAirPorts/Pages/Page02.aspx)
- Dubai Customs – [GCC Common Customs Law](https://www.dubaicustoms.gov.ae/en/OpenData/Publications/COMMON%20CUSTOMS%20LAW%20ENG_A.pdf) · [Passenger guide](https://www.dubaicustoms.gov.ae/en/OpenData/Publications/DC%20Passenger%20Guide_6th%20Edition%202024_V9(EN).pdf)
- Saudi declaration threshold SAR 40,000 – [Gulf Business](https://gulfbusiness.com/2026/saudi-arabia/traveling-to-saudi-new-cash-and-gold-declaration-rules-are-now-in-effect/) · [Khaleej Times](https://www.khaleejtimes.com/business/aviation/uae-travellers-alert-passengers-must-declare-cash-items-worth-more-than-dh58000-when-visiting-sau?amp=1) · [Egypt USD 10,000 rule (older report)](https://gulfnews.com/world/gulf/kuwait/kuwait-warns-citizens-about-new-egypt-cash-rules-1.1166150)
- PDPL – [Al Tamimi: Executive Regulations issued](https://www.tamimi.com/news/from-policy-to-practice-egypt-issues-executive-regulations-of-the-personal-data-protection-law) · [CMS: one-year countdown](https://cms.law/en/are/legal-updates/egypt-s-pdpl-executive-regulations-issued-one-year-compliance-countdown-begins) · [Clyde & Co 2026 update](https://www.clydeco.com/en/insights/2026/01/egypt-regulatory-update-on-data-privacy)
- Payments – [Baker McKenzie: Egypt new regulation on payment solutions](https://insightplus.bakermckenzie.com/bm/banking-finance_1/egypt-new-regulation-on-payment-solutions) · [Andersen: Fintech in Egypt](https://eg.andersen.com/fintech-in-egypt/)
- Postal – [Daily News Egypt: NPA licensing standards for private courier companies](https://www.dailynewsegypt.com/?p=420852)
- Crowd-shipping risk – [Singapore Law Watch: hidden risks of crowdshipping](https://www.singaporelawwatch.sg/Headlines/Paid-to-carry-parcels-overseas-The-hidden-risks-of-crowdshipping) · [Customs warning on carrying parcels for third parties](https://hirunews.lk/goldfmnews/480624/customs-warns-air-passengers-against-transporting-parcels-for-third-parties)

---

## ملخص بالعربية

**هل الفكرة قانونية؟** نعم، يمكن تشغيلها بشكل قانوني بشرط أن تكون المنصة **وسيطاً إلكترونياً فقط**،
لا تستلم الطرود ولا توصلها بنفسها، وأن يحمل المسافر الغرض كأمتعة شخصية مصاحبة له.

**أهم المخاطر وكيف نتعامل معها:**
1. **الجمارك (قانون 207 لسنة 2020 في مصر، والمادة 103 من قانون الجمارك الخليجي الموحد):** الإعفاء للأمتعة الشخصية
   غير التجارية فقط. في السعودية الحد 3,000 ريال، ويسقط الإعفاء عن المسافر المتكرر أو التاجر. الموبايلات لم تعد معفاة في مصر
   منذ 21 يناير 2026 وتُدفع ضريبتها عبر تطبيق "تليفوني". **يجب الإعلان عن أي شيء فوق حد الإعفاء.**
2. **ترخيص البريد والشحن (الهيئة القومية للبريد):** لا تجعل الشركة تستلم أو توصل طروداً، ولا تكتب "شحن" في نشاط السجل التجاري.
   احصل على رأي قانوني مكتوب قبل الإطلاق.
3. **المخدرات والممنوعات:** ممنوع تماماً حمل أي طرد مغلق. المسافر يفتح الغرض ويفحصه ويؤكد ذلك في التطبيق.
4. **المدفوعات (قانون البنك المركزي 194 لسنة 2020 ولائحة مقدمي خدمات الدفع 2025):** لا تحتفظ بأموال العملاء في حساب الشركة.
   استخدم مزود دفع مرخّص (Paymob أو Fawry أو Geidea) لنظام الضمان.
5. **حماية البيانات (قانون 151 لسنة 2020 ولائحته التنفيذية بالقرار 816 لسنة 2025):** فترة توفيق الأوضاع تنتهي تقريباً في نوفمبر 2026.
   تحتاج ترخيصاً من مركز حماية البيانات الشخصية ومسؤول حماية بيانات.

**النموذج الأكثر أماناً:** "اشترِه لي". المسافر يشتري الغرض جديداً من محل بفاتورة باسمه، ويدفع المستلم الثمن والمكافأة عبر نظام الضمان.

> هذا ملخص بحثي وليس استشارة قانونية. راجع محامياً مصرياً ومستخلصاً جمركياً مرخصاً قبل الإطلاق.
