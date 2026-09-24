# momcozy AI — App Privacy draft inventory

Last reviewed from source: 2026-09-24

This is an engineering inventory, not a legal determination. App Store Connect answers must be approved against the production backend, contracts, retention policies, and enabled launch features.

## High-level conclusion

The app handles account information, maternal and baby care/health information, user-created content, device/install identifiers, service orders, and communications. Most of this data is linked to an authenticated account and used for app functionality or personalization. No advertising, ATT prompt, or dedicated analytics SDK was found in the Flutter source/dependency audit, but backend telemetry and every production processor must still be confirmed.

## Code-derived data inventory

| App Privacy area | Examples present in product | Linked to user | Tracking | Primary purpose | Release action |
| --- | --- | --- | --- | --- | --- |
| Contact Info | Email, display name | Yes | Not identified | Account creation, authentication, support | Confirm backend fields and retention |
| User ID | Account ID, baby ID, session/account references | Yes | Not identified | Authentication and data ownership | Declare identifiers as applicable |
| Health & Fitness | Pregnancy/delivery information, lactation, feeding, pumping, sleep, pain/symptoms, mood/energy, baby growth, diapers, motion assessment | Yes | Not identified | App functionality and personalization | Treat as sensitive health-related data; legal review required |
| Sensitive Info | Maternal and baby care details and consultation intake | Yes | Not identified | Care/service functionality | Confirm whether Apple questionnaire maps any fields here |
| User Content | AI prompts/responses, notes, photos, videos, audio, documents, avatars | Yes | Not identified | AI assistance, records, consultation, media preview | Document AI/provider handling, retention, and deletion |
| Purchases | Care order, package, price, checkout/payment status | Yes | Not identified | One-to-one service fulfillment | Confirm whether payment details stay entirely with Stripe |
| Other Financial Info | No card-number collection found in app source | Pending | Not identified | Hosted checkout if enabled | Validate production Stripe flow and backend logs |
| Device ID | App/device installation ID and notification registration | Yes or pseudonymous | Not identified | Session security and push delivery | Confirm exact identifier generation and retention |
| Product Interaction | Notification preferences, schedules, service state, feature actions | Yes | Not identified | App functionality | Confirm backend event/observability storage |
| Diagnostics | Error type, status code, request ID, safe operational metadata | Potentially | Not identified | Reliability/security | Source redaction tests pass; confirm server-side logging |
| Coarse/Precise Location | No iOS Core Location permission is declared | Not found | Not identified | N/A | Confirm server does not infer or collect location beyond user-entered service data |
| Contacts | No contacts permission or address-book integration found | No | Not identified | N/A | Keep undeclared unless feature changes |
| Browsing/Search History | No general browsing history collection found | No | Not identified | N/A | Confirm backend AI/search telemetry |
| Advertising Data | No advertising SDK found | No | Not identified | N/A | Keep tracking disabled unless feature changes |

## Permissions and just-in-time purpose

### Camera

Current purpose string:

```text
用于视频咨询、检查摄像头，以及拍摄你选择提供的照片或视频。
```

Used for device checks, video consultation, selected media capture, and motion assessment. Confirm camera is requested only from an explicit user action and that motion imagery retention matches the privacy policy.

### Microphone

Current purpose string:

```text
用于视频咨询、检查麦克风，以及录制你选择发送的语音消息。
```

Used for device checks, video consultation, and realtime voice/motion guidance. Confirm whether any audio is stored, transcribed, or sent to an AI provider and disclose that behavior.

### Photo Library

Current purpose string:

```text
用于选择头像或母婴场景图片，以生成数字人形象或发送给智能体分析。
```

Used for user-selected images. Confirm generated avatars, AI analysis, retention, and deletion behavior.

### Notifications

The project declares APNs entitlement and background remote notifications. Firebase Messaging auto-init is disabled until the app explicitly enables it. Real APNs/Firebase configuration and device validation are still missing.

## Authentication and account deletion

- Email/password registration and login are implemented.
- Google login and linking are implemented but iOS OAuth configuration is missing.
- Sign in with Apple is not implemented.
- In-app account deletion is implemented. The UI states that access ends immediately and a data-erasure request remains pending.

Legal/backend must confirm:

- deletion includes the entire account rather than only local access;
- associated AI conversations, uploads, baby data, push installations, and service data are erased or retained under a clearly disclosed legal basis;
- any required retention period and status communication are documented;
- the reviewer can complete deletion without contacting support.

## Third-party/service-provider checklist

Confirm production contracts, regions, retention, training/use restrictions, and subprocessors for every enabled service:

- Apple APNs and Firebase Cloud Messaging, if push is enabled;
- Google Sign-In, if Google login is enabled;
- LiveKit/WebRTC infrastructure for consultation;
- Stripe for eligible professional-service checkout;
- AI model/provider services used by the backend;
- cloud hosting, object storage, databases, monitoring, email, and support systems.

## Children and baby data

The app is intended for parents/caregivers but stores information about babies. The policy and App Privacy answers should clearly explain:

- who may create a baby profile;
- parental/caregiver authority and sharing;
- retention and deletion of baby records and media;
- whether any data is used for model training, research, advertising, or profiling;
- regional age/consent rules.

## Privacy manifests

The unsigned iOS build embeds privacy manifests from Flutter, WebRTC, Firebase, Google Sign-In, and multiple plugins. The app target itself does not currently contain `PrivacyInfo.xcprivacy`.

Before submission:

1. produce a signed Xcode archive;
2. generate and inspect the archive privacy report;
3. resolve missing required-reason API declarations or SDK signatures;
4. add an app-owned privacy manifest if the app's direct API use or data declarations require it;
5. make App Store Connect disclosures match actual production behavior.

## Privacy policy gaps to review

The currently linked policy must explicitly cover, or link to an app-specific supplement covering:

- AI prompts, outputs, model providers, human review, and model-training policy;
- maternal/baby health and care records;
- photos, video, audio, documents, and generated avatars;
- one-to-one consultation and provider access;
- motion camera/audio processing;
- push tokens and device identifiers;
- Stripe/service purchase records;
- international/cross-border transfers;
- retention, backup deletion, and legal holds;
- account deletion workflow;
- parent/caregiver handling of baby data;
- support/privacy contact information.
