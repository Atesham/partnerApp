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
                  ? 'यह दस्तावेज स्क्रैपवेल प्लेटफॉर्म पर पार्टनर के रूप में आपकी पात्रता, खाता नियमों और परिचालन दायित्वों को नियंत्रित करता है।'
                  : 'This document governs your eligibility, account rules, and operational obligations as a partner on the Scrapwell platform.',
          sections: [
            _PolicySection(
              title: isHindi ? '1. पात्रता मानदंड' : '1. Eligibility Criteria',
              body:
                  isHindi
                      ? 'भागीदार बनने के लिए आपकी आयु कम से कम 18 वर्ष होनी चाहिए और भारत में एक वैध व्यावसायिक इकाई का प्रतिनिधित्व करना चाहिए। आपको वैध सरकारी पहचान पत्र (आधार, पैन, या जीएसटी) प्रदान करना आवश्यक है।'
                      : 'To register as a partner, you must be at least 18 years old, possess a legally authorized business in India, and provide valid government-issued identification.',
            ),
            _PolicySection(
              title:
                  isHindi
                      ? '2. खाता प्रबंधन और नियम'
                      : '2. Account Management & Rules',
              body:
                  isHindi
                      ? 'प्रत्येक व्यावसायिक इकाई के पास केवल एक पंजीकृत खाता होना चाहिए। सभी प्रदान की गई जानकारी सही होनी चाहिए। खाता साझा करना या अनधिकृत लॉगिन सख्त वर्जित है।'
                      : 'Only one partner account is allowed per business. All registration information must be accurate. Credentials sharing or unauthorized access will result in immediate suspension.',
            ),
            _PolicySection(
              title:
                  isHindi ? '3. परिचालन दायित्व' : '3. Operational Obligations',
              body:
                  isHindi
                      ? 'भागीदार उचित समय पर ग्राहकों से पिकअप सुनिश्चित करेंगे, प्रमाणित डिजिटल तराजू से सटीक वजन दर्ज करेंगे, पूर्व-निर्धारित दरों का पालन करेंगे और व्यावसायिक व्यवहार बनाए रखेंगे।'
                      : 'Partners are obligated to ensure timely customer pickups, perform weight recording using verified digital scales, follow platform rate charts, and maintain professional behavior.',
            ),
            _PolicySection(
              title:
                  isHindi ? '4. खाता निलंबन के अधिकार' : '4. Suspension Rights',
              body:
                  isHindi
                      ? 'स्क्रैपवेल के पास धोखाधड़ी, मंच के बाहर नकद लेनदेन, नकली पिकअप प्रविष्टि, या ग्राहकों के उत्पीड़न के मामलों में खाते को निलंबित या बंद करने के पूर्ण अधिकार सुरक्षित हैं।'
                      : 'Scrapwell reserves the right to temporarily suspend or permanently terminate accounts involved in fraudulent pick-ups, off-platform transactions, scale tampering, or harassment.',
            ),
            _PolicySection(
              title:
                  isHindi ? '5. दायित्व सीमाएं' : '5. Limitation of Liability',
              body:
                  isHindi
                      ? 'स्क्रैपवेल केवल एक तकनीकी प्रदाता है। भागीदार एक स्वतंत्र ठेकेदार के रूप में कार्य करता है और किसी भी प्रत्यक्ष या अप्रत्यक्ष परिचालन घाटे के लिए स्वयं जिम्मेदार है।'
                      : 'Scrapwell acts solely as a lead generation technology platform. The partner functions as an independent contractor, assuming full liability for operations.',
            ),
            _PolicySection(
              title:
                  isHindi
                      ? '6. विवाद और मध्यस्थता'
                      : '6. Dispute & Arbitration',
              body:
                  isHindi
                      ? 'सभी विवाद भारतीय मध्यस्थता अधिनियम के तहत निपटाए जाएंगे। क्षेत्राधिकार गुरुग्राम, हरियाणा की अदालतों का होगा।'
                      : 'All disputes shall be governed by Indian laws and resolved through arbitration in Gurgaon, Haryana under the Indian Arbitration and Conciliation Act.',
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
                  ? 'डीपीडीडी अधिनियम 2023 और आईटी अधिनियम 2000 के तहत आपकी व्यक्तिगत जानकारी को सुरक्षित रखने की हमारी नीतियां।'
                  : 'Details how Scrapwell processes and protects your personal information under the DPDP Act 2023 and IT Act 2000.',
          sections: [
            _PolicySection(
              title: isHindi ? '1. डेटा संग्रह' : '1. Data Collection',
              body:
                  isHindi
                      ? 'हम आपका नाम, संपर्क नंबर, व्यावसायिक पता, बैंक खाते का विवरण और स्थान एकत्र करते हैं ताकि पिकअप सेवाओं का संचालन किया जा सके।'
                      : 'We collect your name, phone number, shop photo, location data, and banking details to process platform registrations, order matches, and settlements.',
            ),
            _PolicySection(
              title:
                  isHindi
                      ? '2. डेटा का उपयोग और साझा करना'
                      : '2. Data Usage & Sharing',
              body:
                  isHindi
                      ? 'आपका डेटा केवल आपके खाते को सत्यापित करने और ऑर्डर मिलान के लिए उपयोग किया जाता है। हम कभी भी किसी तीसरे पक्ष को डेटा नहीं बेचते हैं।'
                      : 'Your data is strictly used for order routing and legal compliance. Sensitive personal information is encrypted and never sold or shared with third-party advertisers.',
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
