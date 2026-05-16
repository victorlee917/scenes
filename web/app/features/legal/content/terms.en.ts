import type { LegalContent } from "../legal-types";

/**
 * Scenes Terms of Service — EN. 실제 구독 모델/페어 단위 혜택 기준으로 작성한 초안.
 * 정식 공개 전 변호사 검토 필요.
 */
export const termsEn: LegalContent = {
  title: "Terms of Service",
  lastUpdated: "Last updated: May 16, 2026",
  blocks: [
    {
      type: "p",
      text: 'These Terms of Service ("Terms") govern your use of the Scenes mobile application and related services (the "Service"). By using Scenes you agree to these Terms. If you do not agree, do not use the Service.',
    },

    { type: "h2", text: "1. Eligibility" },
    {
      type: "p",
      text: "You must be at least the minimum age set by the applicable app store rating for our distribution region and capable of forming a legally binding contract to use Scenes. If you are using Scenes on behalf of another person or entity, you represent that you are authorized to do so.",
    },

    { type: "h2", text: "2. Your Account" },
    {
      type: "ul",
      items: [
        "You are responsible for the confidentiality of your sign-in credentials with your authentication provider.",
        "You may not impersonate another person or misrepresent your affiliation with any person or entity.",
        "You are responsible for all activity that occurs under your account.",
      ],
    },

    { type: "h2", text: "3. Couple Pairing" },
    {
      type: "ul",
      items: [
        "Scenes is designed for two people in a relationship to share a private journal. Pairing requires consent from both partners.",
        "Either partner may end the pairing at any time.",
        "After unpairing, content created during the relationship remains visible to both partners in a read-only mode, unless a partner deletes their account (in which case their identifying information is masked, but the shared content remains for the other partner).",
        "You may only be actively paired with one partner at a time.",
      ],
    },

    { type: "h2", text: "4. Subscription — Scenes HD" },

    { type: "h3", text: "4.1 Plan and Pricing" },
    {
      type: "ul",
      items: [
        "Scenes HD is offered as a monthly auto-renewing subscription at the price displayed in the app at the time of purchase (currently USD $4.99 per month or local equivalent set by the app store).",
        "New subscribers may be eligible for a 7-day free trial. Any unused portion of a free trial is forfeited when you start a paid subscription.",
      ],
    },

    { type: "h3", text: "4.2 Pair Benefit" },
    {
      type: "p",
      text: "A single Scenes HD subscription unlocks Scenes HD features for both members of your active couple pair. Only one partner needs to subscribe for both to receive the benefit. If your pair becomes inactive (e.g., after unpairing) the benefit no longer applies to former partners.",
    },

    { type: "h3", text: "4.3 Billing and Renewal" },
    {
      type: "ul",
      items: [
        "Payment is charged to your Apple ID account (or Google Play account, when available) upon confirmation of purchase.",
        "Your subscription automatically renews unless auto-renew is turned off at least 24 hours before the end of the current period.",
        "Your account will be charged for renewal within 24 hours prior to the end of the current period at the then-current price.",
        "You can manage and cancel your subscription in your App Store or Google Play account settings.",
      ],
    },

    { type: "h3", text: "4.4 Refunds" },
    {
      type: "p",
      text: "Refund requests for in-app purchases are handled by Apple or Google according to their respective refund policies. We are not able to issue refunds for app store transactions directly.",
    },

    { type: "h3", text: "4.5 Changes to Subscription Terms" },
    {
      type: "p",
      text: "We may change subscription pricing or the features included in Scenes HD. Material changes will take effect on your next renewal period and will be communicated in advance through the app.",
    },

    { type: "h2", text: "5. Your Content" },
    {
      type: "ul",
      items: [
        "You retain ownership of the content you upload to Scenes, including photographs, scene titles, comments, and reactions.",
        "You grant us a limited, worldwide, non-exclusive, royalty-free license to host, store, transmit, and display your content solely as necessary to provide the Service to you and your partner.",
        "You represent that you have all rights necessary to upload your content and that your content does not violate any applicable law or third-party right.",
      ],
    },

    { type: "h2", text: "6. Acceptable Use" },
    { type: "p", text: "You agree not to:" },
    {
      type: "ul",
      items: [
        "Upload content that is illegal, infringing, defamatory, sexually exploitative of minors, harassing, or otherwise abusive.",
        "Use Scenes to engage in unlawful conduct or to facilitate illegal activity by another person.",
        "Attempt to access another user's account or content without authorization.",
        "Reverse engineer, decompile, or otherwise attempt to extract source code or unpublished APIs from the Service, except to the extent expressly permitted by law.",
        "Interfere with or disrupt the integrity or performance of the Service.",
      ],
    },
    {
      type: "p",
      text: "We may suspend or terminate accounts that violate these rules.",
    },

    { type: "h2", text: "7. Third-Party Services" },
    {
      type: "p",
      text: "Scenes integrates with third-party services (including Apple, Google, Kakao, Spotify, TMDB, Mapbox, and Firebase Cloud Messaging). Your use of those services through Scenes is also subject to their respective terms.",
    },

    { type: "h2", text: "8. Service Availability" },
    {
      type: "p",
      text: "We aim to keep Scenes available continuously, but we do not guarantee uninterrupted access. Scheduled maintenance, third-party outages, or unforeseen issues may temporarily affect availability.",
    },

    { type: "h2", text: "9. Disclaimer of Warranties" },
    {
      type: "p",
      text: 'Scenes is provided "as is" and "as available" without warranties of any kind, express or implied, to the maximum extent permitted by applicable law. We do not warrant that the Service will be uninterrupted, error-free, or that any data loss will not occur.',
    },

    { type: "h2", text: "10. Limitation of Liability" },
    {
      type: "p",
      text: "To the maximum extent permitted by applicable law, Scenes and its operators shall not be liable for any indirect, incidental, special, consequential, or punitive damages, or any loss of data, content, revenue, or profits, arising out of or related to your use of the Service.",
    },

    { type: "h2", text: "11. Termination" },
    {
      type: "p",
      text: "You may stop using Scenes at any time and delete your account from in-app settings. We may suspend or terminate your access for material violations of these Terms or for legal compliance reasons.",
    },

    { type: "h2", text: "12. Governing Law" },
    {
      type: "p",
      text: "These Terms are governed by the laws of the Republic of Korea, without regard to conflict-of-laws principles. Any disputes shall be resolved exclusively in the courts located in Seoul, Republic of Korea, unless mandatory consumer-protection laws in your jurisdiction provide otherwise.",
    },

    { type: "h2", text: "13. Changes to These Terms" },
    {
      type: "p",
      text: 'We may revise these Terms from time to time. Material changes will be communicated through the app or by email. The "Last updated" date at the top of this page reflects the most recent revision. Your continued use of the Service after a revision constitutes acceptance of the updated Terms.',
    },

    { type: "h2", text: "14. Contact" },
    {
      type: "p",
      text: "For questions about these Terms, please contact us at: support@scenes.app",
    },
  ],
};
