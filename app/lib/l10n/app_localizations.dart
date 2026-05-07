import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ko.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ko'),
  ];

  /// The application name.
  ///
  /// In en, this message translates to:
  /// **'Scenes'**
  String get appTitle;

  /// Couple start date label shown in the home top strip.
  ///
  /// In en, this message translates to:
  /// **'Since {date}'**
  String coupleSince(String date);

  /// Days-since counter in the home top strip.
  ///
  /// In en, this message translates to:
  /// **'d+{days}'**
  String coupleDDay(int days);

  /// Accessibility label for the vertical Scene pager.
  ///
  /// In en, this message translates to:
  /// **'Scenes'**
  String get sceneListA11yLabel;

  /// A11y label for the left transport button (go to sort/list screen).
  ///
  /// In en, this message translates to:
  /// **'Sort scenes'**
  String get transportSort;

  /// A11y label for the center transport button (add new scene).
  ///
  /// In en, this message translates to:
  /// **'Add scene'**
  String get transportAdd;

  /// A11y label for the right transport button (rewind/play back past scenes).
  ///
  /// In en, this message translates to:
  /// **'Play scenes'**
  String get transportPlay;

  /// Label shown in the AddSceneCard (appended at the end of the home carousel, and shown alone when no scenes exist yet).
  ///
  /// In en, this message translates to:
  /// **'add new scene'**
  String get addSceneCardLabel;

  /// First part of the home empty-state tagline, before the highlighted brand word.
  ///
  /// In en, this message translates to:
  /// **'Keep the '**
  String get homeEmptyTaglinePrefix;

  /// Highlighted brand word inside the home empty-state tagline.
  ///
  /// In en, this message translates to:
  /// **'Scenes'**
  String get homeEmptyTaglineBrand;

  /// Last part of the home empty-state tagline, after the highlighted brand word.
  ///
  /// In en, this message translates to:
  /// **'\nwe shared together.'**
  String get homeEmptyTaglineSuffix;

  /// A11y label for the back/close affordance in the scene detail app bar.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get detailBack;

  /// A11y label for the ellipsis button in the scene detail app bar (opens edit/delete menu).
  ///
  /// In en, this message translates to:
  /// **'Scene actions'**
  String get detailMoreActions;

  /// Action label to enter reorder mode for scenes.
  ///
  /// In en, this message translates to:
  /// **'Edit order'**
  String get sceneListEditOrder;

  /// Action label to sort scenes newest-first.
  ///
  /// In en, this message translates to:
  /// **'Newest first'**
  String get sceneListNewestFirst;

  /// Action label to sort scenes oldest-first.
  ///
  /// In en, this message translates to:
  /// **'Oldest first'**
  String get sceneListOldestFirst;

  /// Save button label in scene list reorder mode.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get sceneListSave;

  /// Action label to edit a scene in the detail action sheet.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get sceneDetailEdit;

  /// Action label to delete a scene in the detail action sheet.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get sceneDetailDelete;

  /// A11y label for the share action button in the scene detail.
  ///
  /// In en, this message translates to:
  /// **'Share scene'**
  String get sceneDetailShare;

  /// A11y label for the add-media action button in the scene detail.
  ///
  /// In en, this message translates to:
  /// **'Add to scene'**
  String get sceneDetailAddMedia;

  /// A11y label for the settings button in the profile app bar.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get profileSettings;

  /// Settings screen app bar title.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// Section header for user preference items.
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get settingsSectionPreferences;

  /// Section header for about/legal/links.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsSectionAbout;

  /// Section header for account actions.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get settingsSectionAccount;

  /// No description provided for @settingsTheme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsTheme;

  /// No description provided for @settingsPushNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get settingsPushNotifications;

  /// No description provided for @settingsPrivacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get settingsPrivacyPolicy;

  /// No description provided for @settingsTermsOfService.
  ///
  /// In en, this message translates to:
  /// **'Terms of service'**
  String get settingsTermsOfService;

  /// No description provided for @settingsInstagram.
  ///
  /// In en, this message translates to:
  /// **'Scenes on Instagram'**
  String get settingsInstagram;

  /// No description provided for @settingsLogout.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get settingsLogout;

  /// Action label to disconnect from partner.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get settingsDisconnect;

  /// No description provided for @settingsDeleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get settingsDeleteAccount;

  /// Settings entry that groups destructive actions (disconnect, delete account).
  ///
  /// In en, this message translates to:
  /// **'Danger zone'**
  String get settingsDangerZone;

  /// App bar title for the danger zone screen.
  ///
  /// In en, this message translates to:
  /// **'Danger zone'**
  String get dangerZoneTitle;

  /// Subtitle/description shown at the top of the danger zone screen.
  ///
  /// In en, this message translates to:
  /// **'Actions in this area can\'t be undone.'**
  String get dangerZoneSubtitle;

  /// Progress label shown in the floating upload chip while photos are uploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading {current} of {total}'**
  String uploadChipPhotosProgress(int current, int total);

  /// No description provided for @uploadChipFilmActive.
  ///
  /// In en, this message translates to:
  /// **'Adding film…'**
  String get uploadChipFilmActive;

  /// No description provided for @uploadChipMusicActive.
  ///
  /// In en, this message translates to:
  /// **'Adding music…'**
  String get uploadChipMusicActive;

  /// No description provided for @uploadChipPlaceActive.
  ///
  /// In en, this message translates to:
  /// **'Adding place…'**
  String get uploadChipPlaceActive;

  /// Done label shown briefly after photos finish uploading.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 photo added} other{{count} photos added}}'**
  String uploadChipPhotosDone(int count);

  /// No description provided for @uploadChipFilmDone.
  ///
  /// In en, this message translates to:
  /// **'Film added'**
  String get uploadChipFilmDone;

  /// No description provided for @uploadChipMusicDone.
  ///
  /// In en, this message translates to:
  /// **'Music added'**
  String get uploadChipMusicDone;

  /// No description provided for @uploadChipPlaceDone.
  ///
  /// In en, this message translates to:
  /// **'Place added'**
  String get uploadChipPlaceDone;

  /// No description provided for @uploadChipFailed.
  ///
  /// In en, this message translates to:
  /// **'Upload failed'**
  String get uploadChipFailed;

  /// No description provided for @uploadChipCancelling.
  ///
  /// In en, this message translates to:
  /// **'Cancelling…'**
  String get uploadChipCancelling;

  /// Label shown in place of the actual name for a soft-deleted profile (abandoned couple).
  ///
  /// In en, this message translates to:
  /// **'Deleted user'**
  String get profileDeletedUserName;

  /// A11y label for the play action button in the scene detail.
  ///
  /// In en, this message translates to:
  /// **'Play scene'**
  String get sceneDetailPlay;

  /// Placeholder text shown in scene detail when there is no media yet.
  ///
  /// In en, this message translates to:
  /// **'Fill this Scene with moments that matter.'**
  String get sceneDetailEmptyMedia;

  /// Narrative sentence displayed on the profile screen.
  ///
  /// In en, this message translates to:
  /// **'Since {date}, we have captured {count} Scenes together.'**
  String profileNarrative(
    String partnerA,
    String partnerB,
    String date,
    int count,
  );

  /// Total scene count label shown on the left of the home top strip.
  ///
  /// In en, this message translates to:
  /// **'{count} Scenes'**
  String coupleScenesCount(int count);

  /// Headline of the post-pairing notification permission prompt screen, including the partner's display name.
  ///
  /// In en, this message translates to:
  /// **'Don\'t miss\n{name}\'s updates'**
  String notiPromptTitleWithName(String name);

  /// Headline used when the partner display name isn't available yet.
  ///
  /// In en, this message translates to:
  /// **'Don\'t miss\na single update'**
  String get notiPromptTitleNoName;

  /// Body copy of the notification permission prompt, with partner name.
  ///
  /// In en, this message translates to:
  /// **'Get notified when {name} adds scenes,\nmoments, or reacts to yours.'**
  String notiPromptBodyWithName(String name);

  /// Body copy fallback for the notification permission prompt.
  ///
  /// In en, this message translates to:
  /// **'Get notified when your person adds scenes,\nmoments, or reacts to yours.'**
  String get notiPromptBodyNoName;

  /// Primary button on the notification permission prompt — opens the OS dialog.
  ///
  /// In en, this message translates to:
  /// **'Allow notifications'**
  String get notiPromptAllow;

  /// Secondary action on the notification permission prompt — proceeds without asking.
  ///
  /// In en, this message translates to:
  /// **'Maybe later'**
  String get notiPromptSkip;

  /// Caption under the AddMediaSheet showing how many moments are in the current scene out of the tier's limit.
  ///
  /// In en, this message translates to:
  /// **'Moments {count}/{limit}'**
  String addMediaCapacityLabel(int count, int limit);

  /// Scenes HD banner subtitle — variant about extra media types.
  ///
  /// In en, this message translates to:
  /// **'Unlock films, music, and places.'**
  String get hdBannerBenefitMedia;

  /// Scenes HD banner subtitle — variant about higher per-scene moment cap.
  ///
  /// In en, this message translates to:
  /// **'Up to 100 moments in every scene.'**
  String get hdBannerBenefitMoments;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ko'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ko':
      return AppLocalizationsKo();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
