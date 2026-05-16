import type { LegalContent } from "../legal-types";

/**
 * Scenes Privacy Policy — EN. 실제 데이터/통합 기준으로 작성한 초안.
 * 정식 공개 전 변호사 검토 필요.
 */
export const privacyEn: LegalContent = {
  title: "Privacy Policy",
  lastUpdated: "Last updated: May 16, 2026",
  blocks: [
    {
      type: "p",
      text: 'Scenes ("we", "us", "our") is a private journaling app for couples. This Privacy Policy explains what information we collect, how we use it, and the rights you have over your information. By using Scenes you agree to the practices described here.',
    },

    { type: "h2", text: "1. Information We Collect" },

    { type: "h3", text: "1.1 Account Information" },
    { type: "p", text: "When you sign in, we collect:" },
    {
      type: "ul",
      items: [
        "A unique identifier provided by your sign-in provider (Sign in with Apple, Google Sign-In, or Kakao Login).",
        "Your email address, if your sign-in provider returns it to us.",
        "A display name, which you can edit at any time.",
        "An avatar image, if you choose to upload one.",
        'A "since" date, if you choose to enter the date you and your partner started your relationship.',
      ],
    },

    { type: "h3", text: "1.2 Couple Pairing" },
    {
      type: "p",
      text: "Scenes is designed to be used by two paired partners. Pairing requires explicit consent from both partners and can be ended by either partner at any time. While paired, your display name and avatar are visible to your partner.",
    },

    { type: "h3", text: "1.3 Content You Create" },
    {
      type: "p",
      text: "When you add moments to a scene, we store the content you contribute:",
    },
    {
      type: "ul",
      items: [
        "Photographs you upload (stored in encrypted cloud storage; original files are downscaled and re-encoded before upload).",
        "Film selections, including TMDB identifiers and metadata such as title, year, runtime, and director. Poster images are cached on our servers for playback.",
        "Music selections, including Spotify track identifiers and metadata such as title and artist. Album artwork and previews are loaded directly from Spotify and are not stored on our servers.",
        "Place selections, including coordinates, address, and a cached static map image. Place searches are powered by Apple Maps on iOS and Mapbox on Android; we do not track your device location automatically.",
        "Reactions and comments you add to your partner's moments.",
      ],
    },

    { type: "h3", text: "1.4 Subscription Information" },
    {
      type: "p",
      text: "If you subscribe to Scenes HD, transaction processing is handled by Apple (or Google, when available) and forwarded to us through RevenueCat. We store:",
    },
    {
      type: "ul",
      items: [
        "Your subscription tier and status (active, canceled, expired, etc.).",
        "Your subscription expiration date.",
        "The store provider used for the purchase.",
        "Anonymous original transaction identifiers and a log of subscription lifecycle events for audit purposes.",
      ],
    },
    {
      type: "p",
      text: "We do not see or store your payment card information. All payments are processed by the operating system's in-app purchase service.",
    },

    { type: "h3", text: "1.5 Push Notification Tokens" },
    {
      type: "p",
      text: "If you enable notifications, your device's push token (issued by Firebase Cloud Messaging) is stored so we can deliver alerts about reactions and other in-app events.",
    },

    { type: "h3", text: "1.6 Diagnostic Information" },
    {
      type: "p",
      text: "We may log technical events such as upload failures or backend errors for debugging. We do not embed analytics SDKs or advertising identifiers in the app.",
    },

    { type: "h2", text: "2. How We Use Your Information" },
    {
      type: "ul",
      items: [
        "To operate the Service — store and display your scenes, sync with your partner, manage your subscription.",
        "To send transactional notifications you have opted into.",
        "To diagnose and fix technical issues.",
        "To comply with legal obligations and prevent abuse.",
      ],
    },
    {
      type: "p",
      text: "We do not sell or rent your personal information. We do not use your content for advertising. We do not use your content to train machine learning models.",
    },

    { type: "h2", text: "3. Third-Party Services" },
    {
      type: "p",
      text: "We rely on the following services to operate Scenes. Their privacy practices are governed by their own policies, and we recommend you review them:",
    },
    {
      type: "ul",
      items: [
        "Supabase — backend hosting, authentication, database, and file storage.",
        "Sign in with Apple, Google Sign-In, Kakao Login — authentication providers.",
        "Apple App Store and Google Play — app distribution and in-app purchases.",
        "RevenueCat — subscription lifecycle management.",
        "TMDB (The Movie Database) — film metadata.",
        "Spotify — music metadata and album art delivery.",
        "Mapbox (Android) and Apple Maps (iOS) — place search and map images.",
        "Firebase Cloud Messaging — push notifications.",
      ],
    },

    { type: "h2", text: "4. Data Retention and Deletion" },
    {
      type: "ul",
      items: [
        "You can request account deletion from in-app settings at any time. Deletion is implemented as a soft delete: your profile is marked as deleted, your display name and avatar are masked from your partner, and you can no longer sign back into the deleted account.",
        "Content you contributed to a couple (photographs, films, music, places, reactions) remains associated with the couple pair so that your former partner retains access to the shared timeline. After unpairing or after either partner deletes their account, the pair becomes read-only.",
        "You may revoke the OAuth grant in your sign-in provider's settings at any time (for example, in iOS Settings under Sign in with Apple).",
      ],
    },

    { type: "h2", text: "5. Children's Privacy" },
    {
      type: "p",
      text: "Scenes is not directed to children below the age set by the applicable app store rating for our distribution region. We do not knowingly collect personal information from children. If you believe a child has provided us with personal information, please contact us and we will delete it.",
    },

    { type: "h2", text: "6. Data Location and Transfers" },
    {
      type: "p",
      text: "User data is hosted on Supabase infrastructure. Data may be transferred to and processed in regions where our service providers operate. By using Scenes, you consent to such transfers as necessary to provide the Service.",
    },

    { type: "h2", text: "7. Your Rights" },
    {
      type: "p",
      text: "Depending on your jurisdiction, including under the EU General Data Protection Regulation (GDPR), the California Consumer Privacy Act (CCPA), and Korea's Personal Information Protection Act (PIPA), you may have rights to:",
    },
    {
      type: "ul",
      items: [
        "Access the personal information we hold about you.",
        "Request correction of inaccurate information.",
        "Request deletion of your information (subject to the soft-delete model described in Section 4).",
        "Withdraw consent for processing where consent is the legal basis.",
      ],
    },
    {
      type: "p",
      text: "To exercise these rights, contact us at the address in Section 10.",
    },

    { type: "h2", text: "8. Security" },
    {
      type: "p",
      text: "We use industry-standard practices to protect your information, including transport encryption (HTTPS), encrypted at-rest storage, and short-lived signed URLs for media access. No method of transmission or storage is 100% secure; please use a strong, unique sign-in to your authentication provider and enable two-factor authentication where available.",
    },

    { type: "h2", text: "9. Changes to This Policy" },
    {
      type: "p",
      text: 'We may update this Privacy Policy from time to time. Material changes will be communicated through the app or by email. The "Last updated" date at the top of this page reflects the most recent revision.',
    },

    { type: "h2", text: "10. Contact" },
    {
      type: "p",
      text: "If you have questions about this Privacy Policy or wish to exercise any of the rights described above, please contact us at: support@scenes.app",
    },
  ],
};
