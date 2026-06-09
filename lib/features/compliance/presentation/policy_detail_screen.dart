import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class PolicyDetailScreen extends StatelessWidget {
  final String policyKey;
  final String title;

  const PolicyDetailScreen({
    super.key,
    required this.policyKey,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    final isHindi = locale == 'hi';
    final policy = _getPolicyContent(policyKey, isHindi);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: Text(title), elevation: 0),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary card at top
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primaryLight,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.primary.withOpacity(0.2)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      color: AppTheme.primary,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isHindi ? 'त्वरित सारांश' : 'Quick Summary',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: AppTheme.primaryDark,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            policy.summary,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppTheme.primaryDeep,
                              height: 1.4,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Policy sections
              ...policy.sections.map(
                (sec) => _buildSection(sec.title, sec.body, isHindi),
              ),

              const SizedBox(height: 24),
              // Footer sign off
              Center(
                child: Text(
                  isHindi
                      ? 'अंतिम अद्यतन: 1 जून, 2026'
                      : 'Last Updated: June 1, 2026',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textHint,
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, String body, bool isHindi) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 12),
          const Divider(color: AppTheme.divider, height: 1),
        ],
      ),
    );
  }

  _PolicyData _getPolicyContent(String key, bool isHindi) {
    switch (key) {
      case 'terms':
        return _PolicyData(
          summary:
              isHindi
                  ? 'यह कानूनी दस्तावेज स्क्रैपवेल प्लेटफॉर्म पर पार्टनर के रूप में आपकी पात्रता, स्वतंत्र ठेकेदार संबंधों, खाता नियमों, परिचालन दायित्वों, और विवाद निपटान को नियंत्रित करता है।'
                  : 'This legal document governs your eligibility, independent contractor relationship, account rules, operational obligations, and dispute resolution as a partner on the Scrapwell platform.',
          sections: [
            _PolicySection(
              title: isHindi ? '1. स्वतंत्र ठेकेदार संबंध' : '1. Independent Contractor Relationship',
              body:
                  isHindi
                      ? 'स्क्रैपवेल केवल एक तकनीकी मंच प्रदान करता है। पार्टनर और स्क्रैपवेल के बीच संबंध एक स्वतंत्र ठेकेदार का है, न कि किसी कर्मचारी, एजेंट, या संयुक्त उद्यम का। पार्टनर अपनी मर्जी से काम करने के लिए स्वतंत्र है, और उसके पास काम के घंटे और काम की मात्रा चुनने की पूर्ण स्वतंत्रता है।'
                      : 'This Agreement does not create an employment, agency, joint venture, or partnership relationship between you and Scrapwell. You act solely as an independent contractor. You have the absolute right to determine your own work schedules, choose the orders you accept or decline, and run your business operations independently.',
            ),
            _PolicySection(
              title: isHindi ? '2. पात्रता एवं पंजीकरण' : '2. Eligibility & Registration',
              body:
                  isHindi
                      ? 'भागीदार बनने के लिए आपकी आयु न्यूनतम 18 वर्ष होनी चाहिए। आपके पास भारत में एक वैध व्यवसाय होना चाहिए और सभी आवश्यक कानूनी दस्तावेज (जैसे पैन कार्ड, आधार कार्ड, बैंक खाता विवरण और वैकल्पिक रूप से जीएसटी प्रमाणपत्र) होने अनिवार्य हैं। सभी विवरण सटीक और सत्य होने चाहिए।'
                      : 'To register as a partner, you must be at least 18 years old and legally authorized to operate a scrap collection/recycling business in India. You must provide authentic, updated documentation including Aadhaar, PAN, active bank account details, and GST certificates (where applicable) for identity and fraud-prevention checks.',
            ),
            _PolicySection(
              title: isHindi ? '3. परिचालन दायित्व और दर चार्ट' : '3. Operational Standards & Rate Card',
              body:
                  isHindi
                      ? 'भागीदारों को अनिवार्य रूप से प्रमाणित डिजिटल तराजू (वजन कांटे) का उपयोग करना होगा। यांत्रिक तराजू का उपयोग प्रतिबंधित है। आपको ग्राहक के सामने वास्तविक वजन दर्ज करना होगा और स्क्रैपवेल ऐप पर प्रदर्शित dynamic दरों का पालन करना होगा। दरों में हेरफेर या मूल्य को गलत तरीके से दिखाना सख्त मना है।'
                      : 'Partners must conduct all scrap weighing in front of customers using calibrated, government-certified digital scales. The use of manual spring balances is strictly prohibited. You are obligated to pay customers the exact dynamic rates displayed on the Scrapwell app. Rate manipulation, hidden charges, or scale tampering will lead to immediate account termination.',
            ),
            _PolicySection(
              title: isHindi ? '4. वित्तीय निपटान और सेवा शुल्क (2%)' : '4. Commission & Financial Settlements',
              body:
                  isHindi
                      ? 'प्रत्येक पूर्ण पिकअप मूल्य पर स्क्रैपवेल 2% का सेवा शुल्क (कमीशन) काटेगा। शेष राशि (98%) दैनिक ऑटो-पेआउट के माध्यम से अगले व्यावसायिक दिन (T+1) शाम 6:00 बजे तक आपके सत्यापित बैंक खाते में स्थानांतरित कर दी जाएगी। यदि बैंक सर्वर या गलत क्रेडेंशियल्स के कारण भुगतान विफल होता है, तो राशि वॉलेट में सुरक्षित रखी जाएगी।'
                      : 'Scrapwell charges a flat 2% platform service fee (commission) on the gross value of each successfully completed pickup. Payout settlements for the remaining 98% are processed automatically on a T+1 schedule (by 6:00 PM on the next business day). Failed bank transfers due to incorrect credentials will be safely escrowed in your wallet until banking details are corrected.',
            ),
            _PolicySection(
              title: isHindi ? '5. गैर-बायपास (एंटी-सर्कमवेंशन) नीति' : '5. Anti-Circumvention & Lead Integrity',
              body:
                  isHindi
                      ? 'मंच द्वारा मिले ग्राहकों के साथ कोई भी निजी सौदा करना, भविष्य के लिए व्यक्तिगत संपर्क नंबर साझा करना, या प्लेटफॉर्म शुल्क से बचने के लिए सीधे लेन-देन करना सख्त वर्जित है। स्क्रैपवेल द्वारा प्रदर्शित प्रत्येक पिकअप लीड प्लेटफॉर्म की संपत्ति है। इसका उल्लंघन करने पर खाता स्थायी रूप से बंद किया जा सकता है।'
                      : 'Partners are strictly prohibited from bypassing the Scrapwell platform to conduct direct, offline transactions with customers introduced via the app. Sharing personal mobile numbers for direct future bookings or soliciting platform users off-app violates lead integrity rules. Violations will result in deactivation and holding of outstanding settlements.',
            ),
            _PolicySection(
              title: isHindi ? '6. व्यावसायिक आचरण और सुरक्षा' : '6. Professional Conduct & Safety Protocol',
              body:
                  isHindi
                      ? 'ग्राहकों के साथ हमेशा सम्मानपूर्वक और विनम्रतापूर्वक व्यवहार करें। किसी भी प्रकार की गाली-गलौज, दुर्व्यवहार या अभद्र व्यवहार के लिए मंच पर शून्य सहिष्णुता (जीरो टॉलरेंस) नीति है। भागीदारों को सुरक्षित ड्राइविंग नियमों का पालन करना होगा और पिकअप के दौरान हेलमेट, सुरक्षात्मक जूते और बेल्ट जैसे बुनियादी सुरक्षा उपकरणों का उपयोग करना होगा।'
                      : 'You must maintain a high standard of professional behavior and respect customer privacy. Scrapwell enforces a zero-tolerance policy against physical or verbal abuse, harassment, discrimination, or fraud. Partners must strictly follow transport safety regulations, avoid overloading vehicles, and use proper safety gear during material collection.',
            ),
            _PolicySection(
              title: isHindi ? '7. खाता निलंबन और स्थायी बंदी' : '7. Account Suspension & Termination',
              body:
                  isHindi
                      ? 'स्क्रैपवेल के पास बिना किसी पूर्व सूचना के उन भागीदारों के खातों को निलंबित या स्थायी रूप से बंद करने का अधिकार सुरक्षित है जो: धोखाधड़ी में लिप्त हैं, तराजू में हेरफेर करते हैं, नियमों का उल्लंघन करते हैं, ग्राहकों से दुर्व्यवहार करते हैं, या 4.0 से कम की स्टार रेटिंग बनाए रखते हैं।'
                      : 'Scrapwell reserves the absolute right to temporarily suspend or permanently deactivate accounts for violating platform policies, scale fraud, repeatedly rejecting assigned slots, offline transacting, or failing to maintain a minimum average rating of 4.0 stars.',
            ),
            _PolicySection(
              title: isHindi ? '8. दायित्व सीमाएं और क्षतिपूर्ति' : '8. Limitation of Liability & Indemnity',
              body:
                  isHindi
                      ? 'स्क्रैपवेल केवल एक तकनीकी प्रदाता है और ग्राहकों के आचरण, चोरी, दुर्घटना, या तीसरे पक्ष के नुकसान के लिए उत्तरदायी नहीं है। पार्टनर स्क्रैपवेल, उसके निदेशकों और कर्मचारियों को किसी भी परिचालन घाटे, वाहन दुर्घटनाओं, या कानूनी दावों से पूरी तरह मुक्त (क्षतिपूर्ति) रखने के लिए सहमत है।'
                      : 'Scrapwell operates solely as a digital matching platform and is not liable for customer conduct, transit accidents, scrap ownership disputes, or property damage. You agree to defend, indemnify, and hold harmless Scrapwell and its affiliates from any claims, losses, or legal liabilities arising from your field operations.',
            ),
            _PolicySection(
              title: isHindi ? '9. विवाद और मध्यस्थता' : '9. Dispute Resolution & Governing Law',
              body:
                  isHindi
                      ? 'यह समझौता भारतीय कानूनों द्वारा शासित होगा। दरों, कमीशन, या सेवा से संबंधित किसी भी विवाद का निपटारा आपसी बातचीत या भारतीय मध्यस्थता अधिनियम के तहत गुरुग्राम, हरियाणा में नियुक्त एकल मध्यस्थ के माध्यम से किया जाएगा। गुरुग्राम की अदालतों का विशेष क्षेत्राधिकार होगा।'
                      : 'This agreement is governed by the laws of India. Any dispute, claim, or controversy arising out of or relating to platform usage, payouts, or this agreement shall be settled via binding arbitration in Gurgaon, Haryana under the Indian Arbitration and Conciliation Act. Gurgaon courts shall have exclusive jurisdiction.',
            ),
          ],
        );

      case 'conduct':
        return _PolicyData(
          summary:
              isHindi
                  ? 'सभी भागीदारों से अपेक्षा की जाती है कि वे उच्चतम व्यावसायिक मानकों, ईमानदारी और ग्राहकों के प्रति सम्मान का पालन करें।'
                  : 'All partners are expected to adhere to the highest standards of professional integrity, weight honesty, and customer respect.',
          sections: [
            _PolicySection(
              title: isHindi ? '1. व्यावसायिक आचरण' : '1. Professional Conduct',
              body:
                  isHindi
                      ? 'ग्राहकों के साथ हमेशा सम्मानपूर्वक व्यवहार करें। किसी भी प्रकार की गाली-गलौज, दुर्व्यवहार या अभद्र व्यवहार के लिए मंच पर शून्य सहिष्णुता (जीरो टॉलरेंस) नीति है।'
                      : 'Respect customer privacy. Any forms of verbal abuse, harassment, discrimination, or threat will lead to an immediate lifetime ban.',
            ),
            _PolicySection(
              title: isHindi ? '2. परिचालन ईमानदारी' : '2. Operational Honesty',
              body:
                  isHindi
                      ? 'वजन माप हमेशा सही होना चाहिए। प्रमाणित डिजिटल कांटे का उपयोग करें। दर चार्ट में कोई हेरफेर या मूल्य को गलत तरीके से दिखाना वर्जित है।'
                      : 'Always record exact weights. Use calibrated digital scales. Price manipulation or misleading pricing leads to immediate settlement hold and compliance investigation.',
            ),
            _PolicySection(
              title:
                  isHindi ? '3. प्लेटफॉर्म का दुरुपयोग' : '3. Platform Misuse',
              body:
                  isHindi
                      ? 'अनावश्यक बुकिंग रद्द करना, नकली ग्राहक प्रविष्टियां बनाना या एक ही वाहन के लिए कई खाते खोलना अवैध माना जाएगा।'
                      : 'Fake order creation, deliberate request rejection spams, referral system manipulation, or account sharing is strictly prohibited.',
            ),
          ],
        );

      case 'anti_circumvention':
        return _PolicyData(
          summary:
              isHindi
                  ? 'यह नीति भागीदारों को स्क्रैपवेल प्लेटफॉर्म को बायपास करके ग्राहकों से सीधे संपर्क करने या भुगतान करने से रोकती है।'
                  : 'This policy prohibits partners from taking customers offline or bypassing Scrapwell to avoid commissions and platform rules.',
          sections: [
            _PolicySection(
              title:
                  isHindi
                      ? '1. लेनदेन बायपास का निषेध'
                      : '1. Offline Transaction Ban',
              body:
                  isHindi
                      ? 'मंच द्वारा मिले ग्राहकों के साथ कोई भी निजी सौदा करना, भविष्य के लिए निजी नंबर साझा करना, या प्लेटफॉर्म शुल्क से बचने के लिए सीधे लेनदेन करना प्रतिबंधित है।'
                      : 'Partners are strictly banned from taking platform-introduced customers offline, sharing personal mobile numbers for future direct orders, or offering cash discounts to cancel app requests.',
            ),
            _PolicySection(
              title:
                  isHindi ? '2. लीड स्वामित्व' : '2. Lead Ownership Definition',
              body:
                  isHindi
                      ? 'स्क्रैपवेल के माध्यम से प्राप्त सभी लीड प्लेटफॉर्म की संपत्ति हैं। इन ग्राहकों के साथ भविष्य के सभी लेनदेन केवल स्क्रैपवेल ऐप के माध्यम से ही किए जाने चाहिए।'
                      : 'Customers introduced to partners via Scrapwell remain platform-generated leads. Partners may not bypass Scrapwell processes for repeat services with the same customer.',
            ),
            _PolicySection(
              title:
                  isHindi ? '3. उल्लंघन के परिणाम' : '3. Violation Penalties',
              body:
                  isHindi
                      ? 'नियमों के उल्लंघन पर पहली बार चेतावनी दी जाएगी। बार-बार उल्लंघन करने पर ऑर्डर प्राप्त करने पर सीमाएं लगाई जाएंगी, अथवा खाते को स्थायी रूप से बंद कर दिया जाएगा।'
                      : 'First offense results in a warning. Continued anti-circumvention behavior leads to lead restrictions, wallet holding, temporary suspension, or permanent deactivation.',
            ),
          ],
        );

      case 'lead_ownership':
        return _PolicyData(
          summary:
              isHindi
                  ? 'स्क्रैपवेल द्वारा लाए गए सभी ग्राहकों के अधिकार और लीड स्वामित्व नियमों की व्याख्या।'
                  : 'Defines Scrapwell ownership over platform-generated customer demand and details rules for repeat customers.',
          sections: [
            _PolicySection(
              title: isHindi ? '1. मांग का स्वामित्व' : '1. Demand Ownership',
              body:
                  isHindi
                      ? 'स्क्रैपवेल द्वारा प्रदर्शित प्रत्येक पिकअप लीड प्लेटफॉर्म का है। भागीदार इस डेटा का उपयोग सीधे व्यक्तिगत लाभ या ग्राहकों का डेटाबेस बनाने के लिए नहीं कर सकते हैं।'
                      : 'Every demand lead generated belongs to Scrapwell. Partners receive a non-transferable license to execute that specific pickup request through the application.',
            ),
            _PolicySection(
              title:
                  isHindi
                      ? '2. भविष्य के ऑर्डर नियम'
                      : '2. Repeat Customer Rules',
              body:
                  isHindi
                      ? 'यदि कोई ग्राहक सीधे आपसे पिकअप के लिए संपर्क करता है, तो आपको उन्हें प्लेटफॉर्म के माध्यम से ही बुकिंग करने के लिए कहना होगा।'
                      : 'If a platform-acquired customer contacts a partner directly, the partner must direct the customer to book via Scrapwell. Servicing them directly violates lead rules.',
            ),
          ],
        );

      case 'commission_settlement':
        return _PolicyData(
          summary:
              isHindi
                  ? 'यह कमीशन दरों, शुल्क कटौती, भुगतान आवृत्तियों और बैंक हस्तांतरण प्रक्रियाओं का विवरण देता है।'
                  : 'Details the 2% commission model, fee structures, bank transfer processes, and failed settlement workflows.',
          sections: [
            _PolicySection(
              title:
                  isHindi ? '1. कमीशन मॉडल (2%)' : '1. 2% Commission Structure',
              body:
                  isHindi
                      ? 'प्रत्येक पूर्ण पिकअप मूल्य पर 2% प्लेटफॉर्म सेवा शुल्क काटा जाएगा। शेष राशि आपके वॉलेट/बैंक खाते में जमा की जाएगी।'
                      : 'Scrapwell deducts a flat 2% commission of the total pickup value on each completed order. This fee covers platform tech maintenance and customer lead services.',
            ),
            _PolicySection(
              title: isHindi ? '2. निपटान का समय' : '2. Settlement Cycle',
              body:
                  isHindi
                      ? 'निपटान दैनिक आधार पर ऑटो-पेआउट के माध्यम से किया जाता है। पूरा किया गया लेनदेन अगले व्यावसायिक दिन (T+1) शाम 6:00 बजे तक आपके सत्यापित बैंक खाते में स्थानांतरित कर दिया जाएगा।'
                      : 'Payout settlements are processed daily. All completed transaction balances are dispatched directly to your registered bank account on a T+1 schedule.',
            ),
            _PolicySection(
              title:
                  isHindi ? '3. विफल निपटान समाधान' : '3. Failed Settlements',
              body:
                  isHindi
                      ? 'गलत बैंक जानकारी या बैंक सर्वर में खराबी के कारण विफल निपटान को रोका जाएगा। विवरण सही करने के 48 घंटों के भीतर भुगतान पुनः प्रयास किया जाएगा।'
                      : 'If a bank transfer fails due to incorrect bank credentials, the balance is held safely in your wallet. Payouts retried within 48 hours of verification updates.',
            ),
          ],
        );

      case 'safety':
        return _PolicyData(
          summary:
              isHindi
                  ? 'सड़क सुरक्षा, पिकअप के दौरान सुरक्षा प्रोटोकॉल और सुरक्षा सहायता प्रक्रियाओं की व्याख्या।'
                  : 'Establishes rules for on-road safety, pickup site security, and support for partner protection.',
          sections: [
            _PolicySection(
              title:
                  isHindi ? '1. पिकअप के दौरान सुरक्षा' : '1. On-site Safety',
              body:
                  isHindi
                      ? 'हमेशा ग्राहकों की गोपनीयता और स्थान सुरक्षा का ध्यान रखें। संदिग्ध वस्तुओं या खतरनाक क्षेत्रों में पिकअप न करें।'
                      : 'Prioritize physical safety. Do not enter unstable structures or pick up hazardous substances. You can decline pickups in unsafe environments.',
            ),
            _PolicySection(
              title: isHindi ? '2. वाहन सुरक्षा' : '2. Vehicle Safety',
              body:
                  isHindi
                      ? 'यह सुनिश्चित करें कि आपका वाहन लोड क्षमता के भीतर है और पूरी तरह सुरक्षित है। हेलमेट या सीट बेल्ट का उपयोग अनिवार्य है।'
                      : 'Ensure transport vehicles are not overloaded beyond legal limits. Use secure straps to tie scrap materials. Safety gear like helmets is mandatory.',
            ),
          ],
        );

      case 'pickup_guidelines':
        return _PolicyData(
          summary:
              isHindi
                  ? 'समयबद्धता, सामग्री छँटाई और साइट को साफ रखने के लिए दिशानिर्देश।'
                  : 'Guidelines for punctuality, accurate sorting of materials, and clean handling at pickup sites.',
          sections: [
            _PolicySection(
              title: isHindi ? '1. समय का पाबंद होना' : '1. Punctuality',
              body:
                  isHindi
                      ? 'चुने गए स्लॉट के भीतर ही ग्राहक के घर पहुंचें। किसी भी देरी की सूचना ग्राहक को पहले ही दे दें।'
                      : 'Reach the customer location within the designated time slot. Inform the client immediately in case of unexpected transit delays.',
            ),
            _PolicySection(
              title:
                  isHindi ? '2. छँटाई और स्वच्छता' : '2. Sorting & Cleanliness',
              body:
                  isHindi
                      ? 'सामग्री की जांच करें, ग्राहक के सामने तौलें। कचरा न फैलाएं और तौलने के बाद जगह को साफ छोड़ें।'
                      : 'Carefully sort materials based on category in front of the customer. Do not leave litter behind at the customer\'s premises after weighing.',
            ),
          ],
        );

      case 'customer_interaction':
        return _PolicyData(
          summary:
              isHindi
                  ? 'ग्राहकों के साथ बातचीत और संचार के लिए आचार संहिता।'
                  : 'Rules for communicating with clients respectfully and managing queries professionally.',
          sections: [
            _PolicySection(
              title:
                  isHindi ? '1. सम्मानजनक व्यवहार' : '1. Polite Interactions',
              body:
                  isHindi
                      ? 'ग्राहकों से बात करते समय हमेशा शांत रहें। किसी भी मूल्य विवाद पर शांति से चर्चा करें या ग्राहक सहायता की सहायता लें।'
                      : 'Maintain a polite tone. Explain weights and rates clearly. If a dispute arises over materials, refer the customer to platform support.',
            ),
          ],
        );

      case 'community_standards':
        return _PolicyData(
          summary:
              isHindi
                  ? 'मंच पर सभी भागीदारों के लिए सामान्य सामुदायिक नियम और नैतिक मानदंड।'
                  : 'General community standards and ethical rules expected from all delivery and scrap collection partners.',
          sections: [
            _PolicySection(
              title: isHindi ? '1. निष्पक्षता और सम्मान' : '1. Fair Play',
              body:
                  isHindi
                      ? 'सभी ग्राहकों और अन्य प्रतिस्पर्धी भागीदारों के प्रति निष्पक्ष रहें। बाजार की अखंडता को नुकसान पहुंचाने वाले कार्यों से बचें।'
                      : 'Respect platform mechanics. Avoid manipulating rates or colluding with other buyers to artificially depress local pricing.',
            ),
          ],
        );

      case 'privacy':
        return _PolicyData(
          summary:
              isHindi
                  ? 'यह नीति बताती है कि डिजिटल व्यक्तिगत डेटा संरक्षण (DPDP) अधिनियम 2023 और सूचना प्रौद्योगिकी अधिनियम 2000 के तहत स्क्रैपवेल आपकी व्यक्तिगत जानकारी को कैसे एकत्रित, संसाधित, सुरक्षित और साझा करता है।'
                  : 'This Privacy Policy explains how Scrapwell collects, processes, secures, and discloses your personal data in strict compliance with the Digital Personal Data Protection (DPDP) Act 2023 and the Information Technology Act 2000 of India.',
          sections: [
            _PolicySection(
              title: isHindi ? '1. जानकारी जो हम एकत्र करते हैं' : '1. Information We Collect',
              body:
                  isHindi
                      ? 'हम निम्नलिखित प्रकार के डेटा एकत्र करते हैं: (क) प्रोफ़ाइल जानकारी (नाम, फोन नंबर, व्यावसायिक नाम, दुकान का पता, तस्वीरें); (ख) पहचान दस्तावेज (आधार नंबर, पैन नंबर, बैंक खाता और यूपीआई विवरण); (ग) स्थान डेटा (पिकअप खोज और लाइव नेविगेशन सक्षम करने के लिए पृष्ठभूमि (background) और अग्रभूमि (foreground) में जीपीएस स्थान); (घ) उपयोग और तकनीकी डेटा (डिवाइस की जानकारी, आईपी पता, और ऐप गतिविधि लॉग)।'
                      : 'We collect several types of data to provide and secure our services: (a) Profile and Registration details (your full name, mobile number, shop name, shop address, profile photo); (b) Identity & Verification Documents (Aadhaar number, PAN card, active bank account details, UPI ID); (c) Real-time Location Data (precise GPS coordinates collected in the foreground and background while you are marked online to enable order routing and location-tracking services); (d) Usage and Telemetry details (device identifiers, IP address, operating system, and app crash logs).',
            ),
            _PolicySection(
              title: isHindi ? '2. डेटा उपयोग के कानूनी आधार और उद्देश्य' : '2. Legal Basis & Purposes of Data Usage',
              body:
                  isHindi
                      ? 'हम आपके डेटा का उपयोग निम्नलिखित कानूनी उद्देश्यों के लिए करते हैं: (क) आपके स्थान के आधार पर निकटतम पिकअप ऑर्डर मिलान करने के लिए; (ख) बैंक खातों में कमीशन काटकर सुरक्षित रूप से भुगतान भेजने के लिए; (ग) धोखाधड़ी और तराजू में हेरफेर रोकने के लिए पहचान और पृष्ठभूमि सत्यापन करने हेतु; (घ) सुरक्षा अलर्ट और ग्राहक सेवा प्रदान करने के लिए; और (ङ) कर और ऑडिट से संबंधित वैधानिक आवश्यकताओं का पालन करने के लिए।'
                      : 'We process your personal data under the legal basis of contract performance, consent, and statutory obligations for the following purposes: (a) Matching and routing pickup orders near your location; (b) Processing commission deductions and settling daily payouts directly into your bank account; (c) Authenticating your identity and preventing fraudulent scale or profile activities; (d) Sending safety notifications, location updates, and facilitating customer support; and (e) Complying with tax audit and government regulations in India.',
            ),
            _PolicySection(
              title: isHindi ? '3. डेटा साझा करना और प्रकटीकरण' : '3. Data Sharing & Third-Party Disclosure',
              body:
                  isHindi
                      ? 'हम आपकी गोपनीयता का सम्मान करते हैं। आपकी व्यक्तिगत जानकारी कभी भी विज्ञापनदाताओं को नहीं बेची जाती है। आपका नाम, फोटो, वाहन प्रकार और लाइव लोकेशन केवल उन ग्राहकों के साथ साझा की जाती है जिनका पिकअप ऑर्डर आपने स्वीकार किया है। वित्तीय डेटा को भुगतान गेटवे और सुरक्षा ऑडिटर्स के साथ सुरक्षित रूप से साझा किया जाता है। हम कानूनी वारंट या सरकारी आदेश के तहत आवश्यक होने पर डेटा प्रकट कर सकते हैं।'
                      : 'We do not sell your personal data. We disclose information strictly as follows: (a) Sharing your name, business name, photo, vehicle type, rating, and live GPS location with customers whose order you have accepted to ensure transparency; (b) Sharing financial details with RBI-licensed payment processors to execute settlements; and (c) Disclosing information under statutory obligations, court warrants, or to law enforcement agencies for national security and fraud prevention.',
            ),
            _PolicySection(
              title: isHindi ? '4. डेटा सुरक्षा और सुरक्षा उपाय (DPDP अनुपालन)' : '4. Data Protection & Security Controls (DPDP)',
              body:
                  isHindi
                      ? 'डीपीडीडी अधिनियम 2023 के अनुपालन में, आपकी संवेदनशील जानकारी (जैसे आधार संख्या और बैंक विवरण) मजबूत AES-256 एन्क्रिप्शन और क्रिप्टोग्राफिक टोकनाइजेशन का उपयोग करके संग्रहीत की जाती है। हमारे सर्वर अत्याधुनिक फ़ायरवॉल और सुरक्षा नियंत्रणों से लैस हैं। आधार संख्या के सत्यापन के बाद उसे नष्ट कर दिया जाता है और केवल एक सुरक्षित क्रिप्टोग्राफिक हैश ही डेटाबेस में संग्रहीत रखा जाता है।'
                      : 'In strict compliance with the DPDP Act 2023, Scrapwell employs advanced physical, technical, and administrative security measures. Your sensitive personal data, including bank accounts and identification proof, is encrypted using AES-256 standards both in transit and at rest. Raw Aadhaar numbers are immediately destroyed after successful verification, retaining only a secure SHA-256 cryptographic hash to ensure profile uniqueness.',
            ),
            _PolicySection(
              title: isHindi ? '5. उपयोगकर्ता अधिकार और डेटा प्रतिधारण' : '5. Data Rights & Retention Schedule',
              body:
                  isHindi
                      ? 'आपके पास अपने व्यक्तिगत डेटा तक पहुँचने, उसमें संशोधन करने, या खाता हटाने का अनुरोध करने का पूर्ण अधिकार है। खाता हटाने के बाद, आपके सभी व्यक्तिगत डेटा, पते और चित्र 30 दिनों के भीतर हटा दिए जाते हैं। हालांकि, भारतीय कानूनों (जैसे आयकर अधिनियम) के तहत पिछले वित्तीय रिकॉर्ड और ऑडिट लॉग को 8 वर्षों तक सुरक्षित रखा जाएगा।'
                      : 'You possess explicit rights to access, correct, or request erasure of your personal data. Upon requesting account deletion, we purge all personal metadata, profiles, and shop photos within 30 days. However, under Indian tax laws and RBI guidelines, all past financial transaction records and settlement invoice details will be retained for a statutory period of 8 years in secure archives.',
            ),
          ],
        );

      case 'data_retention':
        return _PolicyData(
          summary:
              isHindi
                  ? 'विभिन्न प्रकार के डेटा के प्रतिधारण की समय सीमा और कानूनी आवश्यकताओं की व्याख्या।'
                  : 'Explains retention schedules of various kinds of data based on audit and legal compliance requirements in India.',
          sections: [
            _PolicySection(
              title:
                  isHindi
                      ? '1. वित्तीय और कर रिकॉर्ड'
                      : '1. Tax & Audit Records',
              body:
                  isHindi
                      ? 'कर कानूनों और कंपनी अधिनियम के अनुसार वित्तीय लेन-देन, कमीशन और भुगतान रिकॉर्ड को न्यूनतम 8 वर्षों के लिए सुरक्षित रखा जाएगा।'
                      : 'Transactional, tax invoices, and commission settlement records are retained for a statutory period of 8 years to satisfy Indian tax audits.',
            ),
            _PolicySection(
              title:
                  isHindi
                      ? '2. सत्यापन और सुरक्षा लॉग'
                      : '2. Fraud & Security Logs',
              body:
                  isHindi
                      ? 'धोखाधड़ी रोकने, सुरक्षा जांच और कानूनी अनुपालन के लिए आपके सत्यापन दस्तावेज (जैसे आधार सत्यापन रिकॉर्ड) खाता बंद होने के बाद भी 3 साल तक सुरक्षित रखे जा सकते हैं।'
                      : 'Verification status metadata and fraud prevention security logs are retained for up to 3 years after account deletion to prevent immediate re-registration by banned actors.',
            ),
          ],
        );

      case 'aadhaar_handling':
        return _PolicyData(
          summary:
              isHindi
                  ? 'यह नीति बताती है कि आधार सत्यापन के दौरान आपकी गोपनीयता कैसे सुरक्षित रखी जाती है और इसका कोई डेटा बेस में स्टोर नहीं होता।'
                  : 'Aadhaar Act compliance details: we discard raw Aadhaar numbers immediately after verification and retain only a tokenized hash.',
          sections: [
            _PolicySection(
              title:
                  isHindi
                      ? '1. केवल सत्यापन हेतु उपयोग'
                      : '1. Identity Check Only',
              body:
                  isHindi
                      ? 'आपका आधार नंबर केवल आपकी पहचान की वास्तविक पुष्टि के लिए उपयोग किया जाता है। स्क्रैपवेल सीधे अपने डेटाबेस में आपके कच्चे आधार नंबर को स्टोर नहीं करता है।'
                      : 'Your Aadhaar is processed solely for verifying registration credentials. Scrapwell does not retain your raw 12-digit Aadhaar number in its permanent databases.',
            ),
            _PolicySection(
              title:
                  isHindi
                      ? '2. सुरक्षित टोकनाइजेशन और हैश'
                      : '2. Cryptographic Tokenization',
              body:
                  isHindi
                      ? 'सत्यापन के तुरंत बाद, आधार संख्या को नष्ट कर दिया जाता है। डेटाबेस में केवल एक सुरक्षित क्रिप्टोग्राफिक हैश (SHA-256) और सत्यापन स्थिति ही रखी जाती है।'
                      : 'Post-verification, the raw number is tokenized and discarded. A secure SHA-256 cryptographic hash is generated and kept to ensure uniqueness and prevent duplicate fake profiles.',
            ),
          ],
        );

      case 'account_deletion':
        return _PolicyData(
          summary:
              isHindi
                  ? 'खाता हटाने की प्रक्रिया के बाद कौन सा डेटा तुरंत हटा दिया जाता है और कौन सा डेटा कानूनों के कारण रखा जाता है।'
                  : 'Details the data deletion workflow: what gets permanently wiped versus what gets archived for statutory compliance.',
          sections: [
            _PolicySection(
              title:
                  isHindi
                      ? '1. व्यक्तिगत डेटा का विलोपन'
                      : '1. Immediate Deletion',
              body:
                  isHindi
                      ? 'जैसे ही आपका खाता विलोपन अनुरोध स्वीकृत होता है, आपकी व्यक्तिगत प्रोफ़ाइल, चित्र, संपर्क जानकारी और प्राथमिकताओं को हटा दिया जाता है।'
                      : 'Upon deletion request approval, all profile images, phone numbers, working preferences, and status details are permanently erased within 30 days.',
            ),
            _PolicySection(
              title:
                  isHindi
                      ? '2. कानूनी आवश्यकताओं के तहत प्रतिधारण'
                      : '2. Compliance Preservation',
              body:
                  isHindi
                      ? 'सरकारी नियमों के अनुपालन के लिए आपके पिछले वित्तीय विवरण और लेन-देन इतिहास को डेटा प्रतिधारण नीति के तहत संग्रहीत रखा जाएगा।'
                      : 'Per RBI and Income Tax guidelines, past transaction histories, tax details, and earnings statements cannot be erased and will be archived securely.',
            ),
          ],
        );

      case 'grievance':
        return _PolicyData(
          summary:
              isHindi
                  ? 'शिकायत निवारण प्रक्रिया, संपर्क अधिकारी की जानकारी और समय सीमा।'
                  : 'Details of the official Grievance Redressal Officer, registered addresses, and resolution timelines.',
          sections: [
            _PolicySection(
              title:
                  isHindi
                      ? '1. शिकायत निवारण अधिकारी'
                      : '1. Grievance Officer Details',
              body:
                  isHindi
                      ? 'नाम: श्री रमेश शर्मा (शिकायत अधिकारी)। ईमेल: grievance@scrapwell.in। पता: सेक्टर 10A, गुरुग्राम, हरियाणा - 122001।'
                      : 'Name: Mr. Saurabh (Grievance Officer)\nEmail: grievance@scrapwell.in\nRegistered Address: Sector 10A, Gurgaon, Haryana - 122001.',
            ),
            _PolicySection(
              title: isHindi ? '2. समाधान समय सीमा' : '2. Turnaround Time',
              body:
                  isHindi
                      ? 'प्राप्त सभी शिकायतों की पुष्टि 48 घंटों में की जाएगी, और अंतिम जांच और समाधान शिकायत प्राप्ति के 15 व्यावसायिक दिनों के भीतर प्रदान किया जाएगा।'
                      : 'All filed disputes will be acknowledged within 48 hours. Legal compliance team will complete review and dispatch final resolution within 15 working days.',
            ),
          ],
        );

      case 'dispute':
        return _PolicyData(
          summary:
              isHindi
                  ? 'भागीदारों और स्क्रैपवेल के बीच विवादों को सुलझाने के लिए औपचारिक कानूनी प्रक्रिया।'
                  : 'Legal framework for resolving contractual conflicts between registered partners and Scrapwell.',
          sections: [
            _PolicySection(
              title:
                  isHindi ? '1. मध्यस्थता प्रक्रिया' : '1. Arbitration Clause',
              body:
                  isHindi
                      ? 'पिकअप, दरों या कमीशन पर किसी भी विवाद को गुरुग्राम में आयोजित होने वाली मध्यस्थता द्वारा हल किया जाएगा। मध्यस्थता अंग्रेजी या हिंदी में होगी।'
                      : 'Any unresolvable dispute relating to commission models or platform usage will be referred to arbitration in Gurgaon. Proceedings will be held in English or Hindi.',
            ),
          ],
        );

      case 'rate_weight':
        return _PolicyData(
          summary:
              isHindi
                  ? 'यह दरों के अनुपालन, कांटे के सत्यापन और वजन विवादों की प्रक्रिया को नियंत्रित करता है।'
                  : 'Governs rates compliance, weighing scale standards, scale verification, and customer weight disputes.',
          sections: [
            _PolicySection(
              title:
                  isHindi ? '1. वजन मापन नियम' : '1. Accurate Weight Standards',
              body:
                  isHindi
                      ? 'भागीदारों को अनिवार्य रूप से प्रमाणित और कैलिब्रेटेड डिजिटल तराजू का उपयोग करना होगा। यांत्रिक तराजू (स्प्रिंग बैलेंस) का उपयोग पूरी तरह प्रतिबंधित है।'
                      : 'Partners must use verified digital scales. Manual spring balances are strictly prohibited. Scales must undergo calibration tests as demanded.',
            ),
            _PolicySection(
              title: isHindi ? '2. दर अनुपालन' : '2. Rate Card Adherence',
              body:
                  isHindi
                      ? 'पिकअप के समय स्क्रैपवेल ऐप पर दिखाई गई दरों का पालन करना आवश्यक है। कम दर देकर ग्राहक का शोषण करना निलंबन का आधार है।'
                      : 'Partners must pay the dynamic rate displayed on the Scrapwell application. Offering lower cash values to customers directly violates platform terms.',
            ),
          ],
        );

      default:
        return _PolicyData(
          summary: 'Scrapwell Policy details',
          sections: [
            _PolicySection(
              title: 'Details',
              body: 'No policy text loaded for this key.',
            ),
          ],
        );
    }
  }
}

class _PolicyData {
  final String summary;
  final List<_PolicySection> sections;
  const _PolicyData({required this.summary, required this.sections});
}

class _PolicySection {
  final String title;
  final String body;
  const _PolicySection({required this.title, required this.body});
}
