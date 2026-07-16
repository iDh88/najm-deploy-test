# Privacy Policy
## Crew Intelligence Platform (CIP) — "Najm / نجم"

**Effective Date:** January 1, 2026
**Last Updated:** January 1, 2026
**Language:** This policy is available in Arabic (العربية) and English. In case of conflict, the Arabic version prevails for users in the Kingdom of Saudi Arabia.

---

## 1. Introduction

Crew Intelligence Platform ("CIP", "Najm", "we", "our", or "us") is an independent software application designed to assist Saudi Airlines cabin crew members with monthly flight scheduling decisions. CIP is **not affiliated with, endorsed by, or connected to** Saudi Arabian Airlines Corporation (Saudia) or any of its subsidiaries.

This Privacy Policy describes how we collect, use, store, and protect your personal data when you use the CIP mobile application and associated services. It is drafted in compliance with the **Personal Data Protection Law (PDPL)** of the Kingdom of Saudi Arabia (Royal Decree No. M/19, dated 9/2/1443H) and its implementing regulations.

By using CIP, you agree to the practices described in this Policy. If you do not agree, please discontinue use of the application.

---

## 2. Data Controller

| Field | Details |
|---|---|
| **Controller Name** | Crew Intelligence Platform (CIP) |
| **Contact Email** | NajmPlatform@gmail.com |
| **Support Email** | NajmAssistance@gmail.com |
| **Data Residency** | Kingdom of Saudi Arabia (Google Cloud `me-central1` region) |

---

## 3. Data We Collect

### 3.1 Data You Provide Directly

| Category | Specific Data | Purpose |
|---|---|---|
| **Account Data** | Full name (Arabic & English), crew ID, email address, phone number, rank, base station | Account creation and authentication |
| **Roster Data** | Monthly flight schedules uploaded via Excel files | Core functionality — schedule analysis and bidding |
| **Preference Data** | Preferred destinations, preferred days off, optimization mode (Money/Rest/Balanced) | Personalized recommendations |
| **Bid & Trade Data** | Bids submitted, trade requests initiated, priorities set | Core service delivery |
| **AI Assistant Data** | Messages sent to Najm assistant | Providing AI responses; quality improvement |

### 3.2 Data Collected Automatically (with consent)

| Category | Specific Data | Purpose | Consent Required |
|---|---|---|---|
| **Behavior Events** | Lines viewed, bids submitted, filters used, mode switches | Improving AI recommendations | ✅ Yes |
| **Preference Vector** | Derived affinity scores for destinations, days, duty patterns | Auto-bid personalization | ✅ Yes |
| **Anonymous Comparisons** | Aggregated, anonymized patterns across users | Collaborative filtering | ✅ Yes (separate) |
| **Device Data** | FCM push token, device OS | Push notifications | Implicit in notification consent |
| **Usage Analytics** | Screen views, session duration, crash reports | App improvement | ✅ Yes |

### 3.3 Data We Do NOT Collect

- Saudi Airlines internal systems, HR data, or payroll data
- Real-time flight tracking or operational data
- Location data (GPS)
- Biometric data
- Financial account details (payment processed by Stripe/HyperPay; we store only subscription status)

---

## 4. How We Use Your Data

| Purpose | Legal Basis (PDPL Art. 6) | Data Used |
|---|---|---|
| Providing core scheduling services | **Contractual necessity** | Roster, bid, trade, account data |
| Sending notifications (bid awards, trade matches) | **Contractual necessity** | Account data, FCM token |
| AI-powered recommendations (Najm) | **Contractual necessity** + **Consent** | Preference vector, behavior events |
| Improving AI accuracy | **Legitimate interest** + **Consent** | Anonymized behavior events |
| Subscription management and billing | **Contractual necessity** | Email, subscription status |
| Security and fraud prevention | **Legitimate interest** | Account data, usage patterns |
| Legal compliance | **Legal obligation** | Any data as required by law |

We **never** use your data for:
- Selling to third parties
- Advertising or marketing by third parties
- Profiling for purposes unrelated to crew scheduling

---

## 5. Data Sharing and Third Parties

We share your data only in the following circumstances:

| Recipient | Purpose | Data Shared | Safeguards |
|---|---|---|---|
| **Google Cloud (Firebase/Firestore)** | Infrastructure and data storage | All app data | Data stored in me-central1 (KSA). Google Cloud DPA in place. |
| **Anthropic (Claude API)** | AI assistant responses | Anonymized message content only — no name, crew ID, or PII | Anthropic Privacy Policy applies. Messages not used for training without consent. |
| **Stripe / HyperPay** | Payment processing | Email, transaction amount | PCI DSS compliant. No full card data stored by CIP. |
| **Firebase Crashlytics** | Crash reporting | Device info, stack traces (no PII) | Google DPA in place. |
| **Law enforcement / regulators** | Legal obligation | Minimum required data | Only when legally compelled with valid order. |

**We never sell your personal data to any third party.**

---

## 6. Data Retention

| Data Category | Retention Period | Basis |
|---|---|---|
| Account data | Duration of account + 30 days after deletion request | Contractual + legal |
| Roster / schedule data | 13 months from upload date | User value + regulatory |
| Bid and trade history | 24 months | User value + audit trail |
| Behavior events (raw) | 24 months, then permanently deleted | Analytics |
| Behavior events (aggregated, anonymized) | Indefinite | Product improvement |
| AI session history | 3 months | Conversational context |
| Audit logs | 5 years | Legal / aviation industry standard |
| Financial transaction records | 7 years | Saudi tax and financial regulation |

---

## 7. Your Rights Under PDPL

As a data subject under the Saudi PDPL, you have the following rights:

### 7.1 Right of Access (Art. 4)
You may request a copy of all personal data we hold about you. We will respond within **30 days**.

### 7.2 Right to Correction (Art. 5)
You may request correction of inaccurate data. Accessible directly via Profile > Edit in the app.

### 7.3 Right to Erasure (Art. 7)
You may request deletion of your account and all associated data. We will process the deletion within **30 days**. Certain data may be retained for the periods specified in Section 6 where legally required.

To request erasure: Settings > Profile > Delete Account, or email NajmPlatform@gmail.com.

### 7.4 Right to Data Portability (Art. 8)
You may request an export of your data in machine-readable format (JSON). Available via Settings > Export My Data.

### 7.5 Right to Withdraw Consent
You may withdraw consent for behavior tracking and collaborative filtering at any time via Settings > Privacy. Withdrawal does not affect the lawfulness of prior processing.

### 7.6 Right to Object
You may object to processing based on legitimate interests. Contact NajmPlatform@gmail.com.

**To exercise any right:** Email NajmPlatform@gmail.com with subject "PDPL Data Request — [Your Name]". We will verify your identity before processing.

---

## 8. Data Security

We implement the following technical and organizational security measures:

| Measure | Details |
|---|---|
| **Encryption in transit** | TLS 1.3 for all data in transit |
| **Encryption at rest** | AES-256 for Firestore data; CMEK for PII fields |
| **Authentication** | Firebase Auth with email verification; MFA for Pro+ tiers |
| **Authorization** | Role-based Firestore security rules; users access only their own data |
| **API security** | Firebase App Check; JWT token expiry 1 hour; refresh token rotation |
| **Service isolation** | Python microservices secured by service account JWT; not publicly exposed |
| **Input validation** | All user inputs sanitized before processing or AI forwarding |
| **Penetration testing** | Annual third-party security assessment |
| **Incident response** | Documented procedure; affected users notified within 72 hours of confirmed breach |
| **Access control** | Principle of least privilege; admin access requires 2FA and audit logging |

---

## 9. International Data Transfers

All primary data is stored in Google Cloud **me-central1 (KSA region)**. Where data is processed by sub-processors outside KSA (e.g., Anthropic for AI in the US), we ensure:

- Adequate data protection measures are in place
- Only the minimum necessary data is transferred (message content is anonymized before Claude API calls)
- Data transfer agreements comply with PDPL cross-border transfer requirements (PDPL Art. 29)

---

## 10. Children's Privacy

CIP is designed for professional use by adult employees of Saudi Airlines. We do not knowingly collect data from persons under 18 years of age. If you believe we have inadvertently collected data from a minor, contact NajmPlatform@gmail.com immediately.

---

## 11. Cookies and Tracking

The CIP mobile application does not use browser cookies. The app uses:
- **Local device storage (Hive):** For offline caching of schedule data. This data stays on your device.
- **Firebase Analytics SDK:** For anonymous usage analytics (can be disabled in Settings).
- **Firebase Crashlytics:** For crash reporting (can be disabled in Settings).

---

## 12. Changes to This Policy

We may update this Policy to reflect changes in our practices or legal requirements. We will notify you of material changes via in-app notification and email at least **30 days** before they take effect. Continued use after notification constitutes acceptance.

---

## 13. Contact Us

**Privacy Officer:** NajmPlatform@gmail.com
**General Support:** NajmAssistance@gmail.com
**Response time:** Within 5 business days for general inquiries; 30 days for formal PDPL requests.

---

*An Arabic translation of this Privacy Policy is not yet published. Request a copy from NajmPlatform@gmail.com.*
*Registered in accordance with the Saudi Personal Data Protection Law (PDPL)*
