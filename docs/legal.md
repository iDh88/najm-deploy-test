# Privacy Policy
## Crew Intelligence Platform (Najm / نجم)
**Last Updated:** January 1, 2026 | **Version:** 1.0

---

## 1. Introduction

Crew Intelligence Platform ("CIP", "Najm", "we", "us") is an unofficial, independent scheduling
assistant application for airline cabin crew. This Privacy Policy explains how we collect, use,
store, and protect your personal information in accordance with the Saudi Personal Data
Protection Law (PDPL) and applicable regulations.

**CIP is NOT affiliated with Saudi Arabian Airlines Corporation (Saudia) or any airline.**

---

## 2. Data We Collect

### 2.1 Information You Provide
| Data Type | Purpose | Retention |
|---|---|---|
| Name, Arabic name | Profile display | Account lifetime + 30 days |
| Employee/Crew ID | Profile identification | Account lifetime + 30 days |
| Email address | Authentication, notifications | Account lifetime + 30 days |
| Phone number (optional) | Account recovery | Account lifetime + 30 days |
| Base station, rank, fleet | Scheduling context | Account lifetime + 30 days |
| Excel roster files | Flight line parsing | 90 days after upload |
| Preferences (destinations, days off) | Personalization | Account lifetime + 30 days |

### 2.2 Information We Generate
| Data Type | Purpose | Retention |
|---|---|---|
| Bid history | Your records, AI learning | 24 months |
| Trade history | Your records, compliance | 24 months |
| App usage events | AI improvement (with consent) | 24 months |
| AI conversation history | Session context | 90 days |
| Device token (FCM) | Push notifications | Until replaced or deleted |

### 2.3 Information We Do NOT Collect
- Actual flight manifests or passenger data
- Real-time flight operational data
- Biometric data
- Financial account information (payment handled by Stripe/HyperPay)
- Location data

---

## 3. How We Use Your Data

| Purpose | Legal Basis |
|---|---|
| Providing the core scheduling service | Contract performance |
| Legality checking and safety validation | Legitimate interest (crew safety) |
| AI assistant responses | Contract performance |
| Personalizing bid and trade suggestions | Consent |
| Learning from your behavior to improve recommendations | Consent (opt-in) |
| Anonymous comparison with similar crew | Consent (opt-in) |
| Sending notifications about bids and trades | Contract performance |
| Security monitoring and fraud prevention | Legitimate interest |
| Compliance with legal obligations | Legal obligation |

---

## 4. Data Sharing

We **do not sell** your personal data. We share data only with:

| Recipient | Data Shared | Purpose |
|---|---|---|
| Google Cloud (Firestore, Cloud Run) | All app data | Hosting and infrastructure |
| Google Firebase | Auth, messaging | Authentication, notifications |
| Anthropic (Claude API) | Anonymized query text | AI assistant responses |
| Stripe | Payment info | Subscription billing |
| HyperPay | Payment info | KSA local payment processing |
| BigQuery | Anonymized behavioral events | Analytics and ML model training |

All third-party processors are contractually bound to PDPL-equivalent data protection standards.

---

## 5. Data Storage & Security

- **Location:** All personal data stored in Google Cloud `me-central1` (Dammam, Saudi Arabia) or `me-west1` (Dubai) region
- **Encryption:** All data encrypted at rest (AES-256) and in transit (TLS 1.3)
- **PII fields:** Name and Crew ID additionally encrypted using Customer-Managed Encryption Keys
- **Access control:** Role-based access; only you can read your data; admin access is logged
- **Behavioral data:** Pseudonymized before analytics processing

---

## 6. Your Rights Under PDPL

You have the right to:

1. **Access:** Request a copy of all data we hold about you
2. **Correction:** Request correction of inaccurate data
3. **Deletion:** Request deletion of your account and all associated data (processed within 30 days)
4. **Portability:** Export your data in JSON format from Settings → Privacy → Export My Data
5. **Objection:** Opt out of behavioral tracking and collaborative filtering at any time
6. **Withdraw Consent:** Revoke consent for optional data uses at any time

**To exercise your rights:** Settings → Privacy, or email NajmPlatform@gmail.com

---

## 7. Data Retention

| Data Category | Retention Period |
|---|---|
| Account and profile data | Duration of account + 30 days after deletion request |
| Flight line data (parsed from Excel) | 90 days after upload |
| Bid and trade history | 24 months |
| Behavioral events | 24 months |
| AI conversation sessions | 90 days |
| Audit logs (bids/trades) | 5 years (regulatory requirement) |
| Anonymized analytics | Indefinite (no PII) |

---

## 8. Children's Privacy

CIP is not intended for persons under 18. We do not knowingly collect data from minors.

---

## 9. Changes to This Policy

We will notify you of material changes via in-app notification and email at least 14 days before the change takes effect.

---

## 10. Contact

**Data Controller:** Crew Intelligence Platform  
**Email:** NajmPlatform@gmail.com  
**Address:** [Registered Address, Saudi Arabia]  

For PDPL complaints, you may also contact the Saudi Data and AI Authority (SDAIA): www.sdaia.gov.sa

---
---

# Terms of Service
## Crew Intelligence Platform (Najm / نجم)
**Last Updated:** January 1, 2026

---

## 1. Acceptance of Terms

By creating an account or using CIP, you agree to these Terms of Service. If you do not agree, do not use the app.

---

## 2. Service Description

CIP ("Najm") is an **unofficial, independent** scheduling assistant tool. It is:
- NOT affiliated with Saudi Arabian Airlines Corporation or any airline
- NOT connected to any airline's internal systems
- Based entirely on data you upload manually

**CIP does not guarantee accuracy of any schedule, legality check, salary estimate, or recommendation.**

---

## 3. Eligibility

You must be:
- 18 years of age or older
- An active or retired airline crew member using the service for legitimate personal scheduling purposes
- Located in a jurisdiction where the service is available

---

## 4. User Responsibilities

You agree to:
- Provide accurate registration information
- Keep your password secure and not share your account
- Upload only your own scheduling data that you are authorized to use
- Not reverse engineer, scrape, or abuse the service
- Not use the service for commercial purposes without written permission
- Not share or redistribute any airline operational data through this platform

You must **always verify** any schedule, legality check, or recommendation through official airline channels before acting on it.

---

## 5. Prohibited Uses

You must NOT:
- Upload confidential airline data you are not authorized to share
- Attempt to disrupt or overload the service
- Use automated tools to query the AI assistant (rate limits apply)
- Impersonate another crew member or airline official
- Use the service in a way that violates GACA regulations or your employment contract

---

## 6. Subscriptions and Payments

- Subscriptions auto-renew unless cancelled at least 24 hours before renewal
- All payments are non-refundable except where required by law (30-day money-back on first Pro subscription)
- Prices are in SAR and include 15% VAT
- Tier downgrades take effect at the end of the billing period
- We reserve the right to change prices with 30 days' notice

---

## 7. Intellectual Property

CIP owns all rights to the application, AI models, scoring algorithms, and platform.  
You retain ownership of the scheduling data you upload.  
You grant CIP a limited license to process your data to provide the service.

---

## 8. Disclaimer of Warranties

**THE SERVICE IS PROVIDED "AS IS" WITHOUT WARRANTIES OF ANY KIND.**

CIP makes no warranty that:
- Legality checks are complete or accurate under all applicable regulations
- Salary estimates reflect actual pay
- Bid suggestions will result in favorable outcomes
- The service will be uninterrupted or error-free

**Always verify legality and schedules with your airline and GACA directly.**

---

## 9. Limitation of Liability

To the maximum extent permitted by law, CIP's total liability shall not exceed the amount you paid for the service in the 3 months preceding the claim.

CIP is not liable for:
- Incorrect scheduling decisions made based on app recommendations
- Employment consequences arising from bid or trade decisions
- Any data loss beyond what is recoverable from our backups
- Indirect, incidental, or consequential damages

---

## 10. Termination

We may suspend or terminate your account if you violate these terms. You may close your account at any time from Settings → Profile → Delete Account.

---

## 11. Governing Law

These terms are governed by the laws of Saudi Arabia. Disputes shall be resolved in the courts of Riyadh.

---

## 12. Contact

NajmPlatform@gmail.com
