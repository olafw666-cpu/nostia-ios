// Legal document text is stored here so it can be updated without rewriting the screen component.
// Update the version constant and body text together whenever legal updates these documents.

enum LegalDocuments {
    static let tosVersion = "2026-06-24"

    static let termsOfUse = """
TERMS OF USE

Effective Date: June 24, 2026

Welcome to Nostia ("the App," "we," "our," or "us"). By creating an account and using Nostia, you agree to be bound by these Terms of Use. Please read them carefully.

1. ACCEPTANCE OF TERMS

By accessing or using Nostia, you confirm that you are at least 13 years of age, that you have read and understood these Terms, and that you agree to be legally bound by them. If you do not agree, do not use the App.

2. DESCRIPTION OF SERVICE

Nostia is a social travel application that allows users to plan trips, split expenses, discover local events, follow other users, and share content. Features include but are not limited to: trip vaults (shared expense tracking), event creation and discovery, direct messaging between mutual followers, a social feed, and map-based event exploration.

3. ACCOUNT REGISTRATION

You must register for an account to use most features of Nostia. You agree to:
- Provide accurate, current, and complete information during registration
- Maintain the security of your password and account credentials
- Notify us immediately of any unauthorized access to your account
- Accept responsibility for all activity that occurs under your account

You may not use another person's account without their permission. Accounts are non-transferable.

4. USER CONDUCT

You agree not to use Nostia to:
- Post, upload, or share content that is unlawful, harmful, threatening, abusive, harassing, defamatory, obscene, or otherwise objectionable
- Impersonate any person or entity or misrepresent your affiliation with any person or entity
- Engage in spam, phishing, or any form of unsolicited commercial communications
- Upload or transmit viruses, malware, or other harmful code
- Interfere with or disrupt the integrity or performance of the App or its servers
- Attempt to gain unauthorized access to any systems or networks connected to Nostia
- Scrape, crawl, or extract data from the App by automated means without our prior written consent
- Violate any applicable local, national, or international law or regulation

ZERO TOLERANCE POLICY: Nostia has no tolerance for objectionable content or abusive users. Objectionable or abusive content may be removed without notice, and offending accounts may be suspended or permanently terminated. Nostia provides in-app tools to flag objectionable content and to block abusive users; flagged content is reviewed and acted on within 24 hours.

5. USER CONTENT

By posting content to Nostia (including text, photos, event information, and other materials), you grant Nostia a non-exclusive, royalty-free, worldwide, sublicensable license to use, display, reproduce, modify, and distribute that content in connection with operating and improving the App.

You represent and warrant that you own or have the necessary rights to the content you post, and that your content does not infringe any third-party intellectual property, privacy, or other rights.

We reserve the right to remove content that violates these Terms or that we deem inappropriate, without prior notice.

6. PAYMENT FEATURES (VAULT)

The Vault feature enables shared expense tracking and payment splitting via Stripe. By using Vault payment features, you agree to Stripe's Terms of Service in addition to these Terms. We are not responsible for any payment failures, disputes, or errors arising from Stripe's processing. You are responsible for ensuring your payment information is accurate.

7. LOCATION DATA

The App may request access to your device's location to enable map-based features, event discovery, and location sharing. Location access is optional but may limit functionality if denied. See our Privacy Policy for details on how location data is used.

8. INTELLECTUAL PROPERTY

All content, design, graphics, interfaces, and software that are part of the App are the exclusive property of Nostia or its licensors, protected by applicable intellectual property laws. You may not copy, modify, distribute, or reverse-engineer any part of the App without our prior written consent.

9. THIRD-PARTY SERVICES

Nostia integrates with third-party services including Stripe for payments and Apple Push Notification service for notifications. Your use of those services is subject to their respective terms and privacy policies. We are not responsible for third-party services.

10. DISCLAIMERS

THE APP IS PROVIDED "AS IS" AND "AS AVAILABLE" WITHOUT WARRANTIES OF ANY KIND, EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, OR NON-INFRINGEMENT. WE DO NOT WARRANT THAT THE APP WILL BE ERROR-FREE, UNINTERRUPTED, OR FREE OF HARMFUL COMPONENTS.

11. LIMITATION OF LIABILITY

TO THE MAXIMUM EXTENT PERMITTED BY APPLICABLE LAW, NOSTIA AND ITS AFFILIATES, OFFICERS, EMPLOYEES, AND LICENSORS SHALL NOT BE LIABLE FOR ANY INDIRECT, INCIDENTAL, SPECIAL, CONSEQUENTIAL, OR PUNITIVE DAMAGES ARISING FROM YOUR USE OF OR INABILITY TO USE THE APP.

12. TERMINATION

We reserve the right to suspend or terminate your account at any time for violation of these Terms, or for any other reason at our discretion. You may delete your account at any time through the Privacy settings in the App.

13. CHANGES TO TERMS

We may update these Terms from time to time. If we make material changes, we will notify you within the App. Continued use of the App after changes take effect constitutes acceptance of the updated Terms.

14. GOVERNING LAW

These Terms shall be governed by and construed in accordance with applicable law. Any disputes shall be resolved through binding arbitration or in the courts of competent jurisdiction.

15. PUSH NOTIFICATIONS

With your permission, Nostia sends push notifications for time-sensitive activity such as expense and payment reminders, new followers, event invitations, being added to a vault, and payments you receive. To deliver them we store a push token for each device on which you enable notifications. Push notifications are optional: you can turn them off at any time from the App's notification settings or your device settings, and doing so does not disable in-app notifications. See our Privacy Policy for details on the data involved.

16. ACCESSIBILITY

Nostia is committed to making the App accessible to everyone, including people with disabilities, and designs its primary user flows to target conformance with the Web Content Accessibility Guidelines (WCAG) 2.1 Level AA. This includes support for VoiceOver, Dynamic Type, Reduce Motion, and cues that do not rely on color alone. Accessibility is an ongoing effort; if you encounter a barrier that prevents you from using any part of the App, please contact us through the App's support channels so we can address it.

17. CONTACT

For questions about these Terms, contact us through the App's support channels.
"""

    static let privacyPolicy = """
PRIVACY POLICY

Effective Date: June 24, 2026

This Privacy Policy describes how Nostia ("we," "our," or "us") collects, uses, shares, and protects information about you when you use the Nostia mobile application.

1. INFORMATION WE COLLECT

a) Information You Provide
- Account information: username, full name, email address, password (stored hashed), and profile picture
- Profile content: bio, profile photo
- User-generated content: posts, comments, event descriptions, trip details
- Payment information: processed by Stripe; we store only a Stripe customer ID and the last four digits of saved cards
- Location data: if you grant location permission, your approximate coordinates are used for event discovery and map features
- Contacts: if you grant Contacts permission and use the optional "find friends from contacts" feature, email addresses from your address book are transmitted to our server solely to check which of them belong to existing Nostia users; they are matched in memory and not stored. If you explicitly invite a specific contact, that contact's email and/or phone number is stored only to generate the invitation link, and the record expires after 7 days. Contact data is never used for advertising and never shared with third parties.

b) Information Collected Automatically
- Device identifiers and platform information for push notifications
- App usage logs for debugging and improving the service
- IP address and user-agent string recorded at account creation and login for security purposes

c) Information From Third Parties
- Stripe provides payment processing status and webhook events related to your transactions

2. HOW WE USE YOUR INFORMATION

We use the information we collect to:
- Provide, operate, and maintain the Nostia service
- Enable social features including following, messaging, and event discovery
- Process vault payments and expense splits via Stripe
- Send in-app notifications and push notifications (where consented)
- Monitor for security threats, fraud, and abuse
- Comply with legal obligations
- Improve and develop new features

We do not use your information for targeted advertising.

3. HOW WE SHARE YOUR INFORMATION

We do not sell your personal information. We may share information in the following limited circumstances:

a) With Other Users
Content you post publicly (feed posts, public events) is visible to other Nostia users. Your username and profile picture are visible when you interact socially on the platform. Direct messages are visible only to you and the recipient.

b) With Service Providers
We share data with Stripe (payment processing) and Apple (push notifications) solely to operate those features.

c) For Legal Reasons
We may disclose information if required by law, regulation, or legal process, or to protect the rights, property, or safety of Nostia, its users, or the public.

d) Business Transfers
In the event of a merger, acquisition, or asset sale, your information may be transferred to the successor entity.

4. DATA RETENTION

We retain your account data for as long as your account is active. You may request deletion of your account and associated data at any time through the Privacy settings in the App. Certain data may be retained for a limited period after deletion to comply with legal obligations or resolve disputes.

5. SECURITY

We implement reasonable technical and organizational measures to protect your information against unauthorized access, alteration, disclosure, or destruction. Passwords are stored using industry-standard bcrypt hashing. Short-lived JWTs are used for session management. No method of transmission or storage is completely secure, and we cannot guarantee absolute security.

6. LOCATION DATA

We only collect precise location data if you explicitly grant location permission on your device. Location data is used to:
- Show nearby events on the map
- Enable location-based event creation
- Periodically sync your approximate location for friend-map features

You can revoke location permission at any time in your device Settings.

7. PUSH NOTIFICATIONS

If you grant permission, Nostia sends push notifications for high-priority activity, including expense and payment reminders, new followers, event invitations, being added to a vault, and payments you receive. To deliver them, we store a push token for each device on which you enable notifications, associated with your account. Tokens are used only to route notifications through Apple Push Notification service and are removed when they become invalid or when you disable notifications. You can turn push notifications off at any time from the App's notification settings or your device Settings; doing so does not affect in-app notifications.

8. CHILDREN'S PRIVACY

Nostia is not directed to children under 13 years of age. We do not knowingly collect personal information from children under 13. If you believe we have inadvertently collected such information, please contact us and we will delete it promptly.

9. YOUR RIGHTS

Depending on your jurisdiction, you may have the right to:
- Access the personal data we hold about you
- Correct inaccurate data
- Request deletion of your data
- Export your data in a portable format

You can exercise these rights through the Privacy settings in the App (Data Export, Delete My Data) or by contacting us directly.

10. CHANGES TO THIS POLICY

We may update this Privacy Policy periodically. If we make material changes, we will notify you within the App. Your continued use of Nostia after changes take effect constitutes acceptance of the updated policy.

11. ACCESSIBILITY

Nostia is committed to accessibility and designs its primary user flows to target conformance with the Web Content Accessibility Guidelines (WCAG) 2.1 Level AA, including support for VoiceOver, Dynamic Type, Reduce Motion, and non-color status cues. Enabling these assistive features does not change what personal data we collect about you. If you encounter an accessibility barrier, please contact us through the App's support channels.

12. CONTACT

For privacy-related questions or requests, use the Data Export or Delete My Data features in the App's Privacy settings, or contact us through our support channels.
"""

    static let communityGuidelines = """
COMMUNITY GUIDELINES

Effective Date: June 11, 2026

Nostia is a platform built around shared travel experiences, adventure, and genuine human connection. These Community Guidelines describe the standards we expect all users to uphold to keep Nostia a safe, welcoming, and enjoyable place.

By using Nostia, you agree to follow these guidelines. Violations may result in content removal, account suspension, or permanent ban.

1. BE RESPECTFUL

Treat everyone on the platform with basic courtesy and respect. Harassment, bullying, threats, and hate speech are not tolerated.

- Do not send unsolicited threatening, abusive, or sexually explicit messages
- Do not target users based on race, ethnicity, nationality, gender, sexual orientation, religion, disability, or any other protected characteristic
- Do not incite violence or threats against individuals or groups

2. KEEP IT AUTHENTIC

Nostia works because users can trust that the people and content they encounter are genuine.

- Use your real identity or a consistent personal identity. Impersonating another person or creating fake accounts is prohibited.
- Do not post misleading, deceptive, or fabricated event information
- Do not manipulate likes, follows, or engagement through bots or coordinated inauthentic behavior
- Do not claim credit for content or experiences that are not yours

3. SHARE RESPONSIBLY

- Only post content you have the right to share. Do not post copyrighted material without permission.
- Do not post personal information (phone numbers, home addresses, financial details) of other people without their explicit consent
- Do not share content designed to shock, disgust, or disturb without contextual necessity

4. NO ILLEGAL ACTIVITY

Nostia may not be used to plan, facilitate, promote, or discuss illegal activities, including but not limited to:
- Drug trafficking or the sale of illegal substances
- Weapons trafficking
- Fraud, scams, or financial crimes
- Human trafficking or exploitation

Reporting suspicious activity to local authorities and to us via the App is encouraged.

5. KEEP PAYMENTS HONEST

The Vault expense-splitting feature is designed to help groups share costs fairly.
- Do not use Vault to commit fraud, charge-backs, or payment abuse
- Do not create false expenses or manipulate payment records
- Disputes about payments should be resolved between the parties involved; Nostia does not mediate financial disputes

6. PROTECT MINORS

Content that sexualizes, exploits, or endangers minors is strictly prohibited and will be reported to appropriate authorities. Nostia is not intended for users under 13.

7. EVENT STANDARDS

Events created on Nostia must:
- Accurately describe the event's time, location, and nature
- Not be used to organize illegal gatherings or activities
- Not promote violence, hate, or dangerous behavior

Event organizers are responsible for ensuring their events comply with local laws and regulations, including applicable permits, capacity limits, and safety requirements.

8. PRIVACY

Respect the privacy of others:
- Do not record or photograph people in private settings without their consent
- Do not share private conversations, messages, or location data of other users without permission
- Do not attempt to access another user's account or private data

9. REPORTING VIOLATIONS

If you see content or behavior that violates these guidelines, use the in-app reporting features (the Report option on any post, comment, message, or profile) or contact us through support. You can also block any user from their profile or from any of their content — blocking immediately removes their content from your feed and prevents them from contacting you. We review all reports within 24 hours and take appropriate action, which may include removing content, warning users, or banning accounts.

We appreciate users who help keep Nostia safe.

10. ENFORCEMENT

Nostia has zero tolerance for objectionable content and abusive users, and reserves the right to:
- Remove any content that violates these guidelines
- Issue warnings for first-time or minor violations
- Suspend accounts temporarily for repeated violations
- Permanently ban accounts for severe or persistent violations

We may act immediately and without prior notice when user safety is at risk.

11. UPDATES

These guidelines may be updated as Nostia evolves. Significant changes will be communicated within the App. Your continued use of Nostia signifies acceptance of the current guidelines.

Thank you for being part of the Nostia community and helping keep it a great place to explore, connect, and adventure together.
"""
}
