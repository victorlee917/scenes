// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Scenes';

  @override
  String coupleSince(String date) {
    return 'Since $date';
  }

  @override
  String coupleDDay(int days) {
    return 'd+$days';
  }

  @override
  String get sceneListA11yLabel => 'Scenes';

  @override
  String get transportSort => 'Sort scenes';

  @override
  String get transportAdd => 'Add scene';

  @override
  String get transportRecap => 'Rewind';

  @override
  String get addSceneCardLabel => 'add new scene';

  @override
  String get homeEmptyTaglinePrefix => 'Keep the ';

  @override
  String get homeEmptyTaglineBrand => 'Scenes';

  @override
  String get homeEmptyTaglineSuffix => '\nwe shared together.';

  @override
  String get detailBack => 'Back';

  @override
  String get detailMoreActions => 'Scene actions';

  @override
  String get sceneListEditOrder => 'Edit order';

  @override
  String get sceneListNewestFirst => 'Newest first';

  @override
  String get sceneListOldestFirst => 'Oldest first';

  @override
  String get sceneListSave => 'Save';

  @override
  String get sceneDetailEdit => 'Edit scene';

  @override
  String get sceneDetailEditDate => 'Edit date';

  @override
  String get sceneDetailEditDateSheetTitle => 'Edit date';

  @override
  String get sceneDetailEditDateSheetInfo =>
      'Sets the date for every moment in this scene.';

  @override
  String get sceneDetailEditDateFailedToast => 'Failed to update dates.';

  @override
  String get actionDelete => 'Delete';

  @override
  String get actionRemove => 'Remove';

  @override
  String get reactionPickerUpdate => 'Update';

  @override
  String get reactionPickerCommentHint => 'Leave a comment (optional)';

  @override
  String get reactionPickerHdUpsellSubtitle =>
      'Add a comment to your reaction.';

  @override
  String get sceneDetailShare => 'Share scene';

  @override
  String get sceneDetailAddMedia => 'Add to scene';

  @override
  String get profileSettings => 'Settings';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsSectionPreferences => 'Preferences';

  @override
  String get settingsSectionAbout => 'About';

  @override
  String get settingsSectionAccount => 'Account';

  @override
  String get settingsTheme => 'Theme';

  @override
  String get settingsPushNotifications => 'Notifications';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get languageScreenTitle => 'Language';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageKorean => '한국어';

  @override
  String get languageSystem => 'Use device language';

  @override
  String get themeScreenTitle => 'Theme';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeLight => 'Light';

  @override
  String get themeSystem => 'Use device theme';

  @override
  String get settingsPrivacyPolicy => 'Privacy policy';

  @override
  String get settingsTermsOfService => 'Terms of service';

  @override
  String get settingsInstagram => 'Scenes on Instagram';

  @override
  String get settingsLogout => 'Sign Out';

  @override
  String get settingsDisconnect => 'Disconnect';

  @override
  String get settingsDeleteAccount => 'Delete account';

  @override
  String get settingsDangerZone => 'Danger zone';

  @override
  String get dangerZoneTitle => 'Danger zone';

  @override
  String uploadChipPhotosProgress(int current, int total) {
    return 'Uploading $current of $total';
  }

  @override
  String get uploadChipFilmActive => 'Adding film…';

  @override
  String get uploadChipMusicActive => 'Adding music…';

  @override
  String get uploadChipPlaceActive => 'Adding place…';

  @override
  String uploadChipPhotosDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count photos added',
      one: '1 photo added',
    );
    return '$_temp0';
  }

  @override
  String get uploadChipFilmDone => 'Film added';

  @override
  String get uploadChipMusicDone => 'Music added';

  @override
  String get uploadChipPlaceDone => 'Place added';

  @override
  String get uploadChipFailed => 'Upload failed';

  @override
  String get uploadChipCancelling => 'Cancelling…';

  @override
  String get profileDeletedUserName => 'Deleted user';

  @override
  String get actionSave => 'Save';

  @override
  String get imageCropperTitle => 'Crop';

  @override
  String get editProfileNameHint => 'Name';

  @override
  String get editProfileSaveFailed => 'Save failed.';

  @override
  String get createSceneTitleHint => 'Scene title';

  @override
  String get createSceneCreate => 'Create';

  @override
  String get createSceneSaveFailed => 'Failed to save scene.';

  @override
  String get datePickerConfirm => 'Confirm';

  @override
  String get mediaLabelPhoto => 'Photo';

  @override
  String get mediaLabelFilm => 'Film';

  @override
  String get mediaLabelMusic => 'Music';

  @override
  String get mediaLabelPlace => 'Place';

  @override
  String get recapEmptyPhotos => 'No photos to rewind yet.';

  @override
  String get recapEmptyFilms => 'No films to rewind yet.';

  @override
  String get recapEmptyMusic => 'No songs to rewind yet.';

  @override
  String get recapEmptyPlaces => 'No places to rewind yet.';

  @override
  String get recapFilteredEmptyPhotos => 'No photos in selected scenes.';

  @override
  String get recapFilteredEmptyFilms => 'No films in selected scenes.';

  @override
  String get recapFilteredEmptyMusic => 'No songs in selected scenes.';

  @override
  String get recapFilteredEmptyPlaces => 'No places in selected scenes.';

  @override
  String get reactionSaveFailed => 'Failed to save reaction.';

  @override
  String get reactionRemoveFailed => 'Failed to remove reaction.';

  @override
  String get recapNavPrevious => 'Previous';

  @override
  String get recapNavNext => 'Next';

  @override
  String get recapNavPreviousPlace => 'Previous place';

  @override
  String get recapNavNextPlace => 'Next place';

  @override
  String get recapTicketReleased => 'Released';

  @override
  String get recapTicketRuntime => 'Runtime';

  @override
  String get recapTicketWatched => 'Watched';

  @override
  String runtimeMinutesValue(int minutes) {
    return '${minutes}min';
  }

  @override
  String runtimeMinutesValueSpaced(int minutes) {
    return '$minutes min';
  }

  @override
  String get contentDetailFilmMovie => 'Movie';

  @override
  String get contentDetailFilmTvSeries => 'TV Series';

  @override
  String get contentDetailMusicTrack => 'Track';

  @override
  String get contentDetailMusicAlbum => 'Album';

  @override
  String get contentDetailUpdateDateFailed => 'Failed to update date.';

  @override
  String get contentDetailDeleteMessage =>
      'It will be removed from this scene.';

  @override
  String get contentDetailDeleteFailed => 'Failed to delete.';

  @override
  String get actionApply => 'Apply';

  @override
  String get uploadCancelDialogMessage => 'Photos already uploaded will stay.';

  @override
  String get uploadCancelKeepUploading => 'Keep uploading';

  @override
  String get filterScenesAll => 'All scenes';

  @override
  String get playSceneAction => 'Play';

  @override
  String get playSceneStop => 'Stop';

  @override
  String get playSceneNoMomentsToast => 'No moments to play.';

  @override
  String get playSceneLoadingPreparing => 'Preparing the scene…';

  @override
  String get playSceneFilterNormal => 'Normal';

  @override
  String get playSceneFilterVintage => 'Vintage';

  @override
  String get playSceneFilterCinema => 'Cinema';

  @override
  String get playSceneFilterMono => 'Mono';

  @override
  String get playSceneSelectMoments => 'Select Moments';

  @override
  String playSceneMomentsCount(int count) {
    return '$count moments';
  }

  @override
  String get playSceneShuffle => 'Shuffle';

  @override
  String get playSceneHdUpsellSubtitle => 'Apply film looks to your playback.';

  @override
  String get playSceneShareFailedToast => 'Share failed.';

  @override
  String get playScenePhotoPermissionToast => 'Photo permission required.';

  @override
  String get playSceneSavedToPhotosToast => 'Saved to Photos';

  @override
  String get playSceneInstagramMissingToast => 'Instagram is not installed.';

  @override
  String get playSceneShareStory => 'Story';

  @override
  String get playSceneShareMore => 'More';

  @override
  String get photoPickerScreenTitle => 'Add Photos';

  @override
  String get photoPickerEmpty => 'No photos found';

  @override
  String get photoPickerAllPhotos => 'All Photos';

  @override
  String photoPickerBatchCapToast(int limit) {
    return 'Up to $limit photos per upload.';
  }

  @override
  String get photoPickerSceneCapToast => 'Scene\'s upload limit reached.';

  @override
  String get pickerSearchFailed => 'Search failed. Please try again.';

  @override
  String get pickerNoResults => 'No results found.';

  @override
  String get filmPickerScreenTitle => 'Add Film';

  @override
  String get filmPickerSearchHint => 'Search films…';

  @override
  String get filmPickerEmpty => 'Search for a film to add.';

  @override
  String get filmPickerTmdbAttribution => 'Movie data provided by TMDB';

  @override
  String get musicPickerScreenTitle => 'Add Music';

  @override
  String get musicPickerSearchHint => 'Search music…';

  @override
  String get musicPickerEmpty => 'Search for music to add.';

  @override
  String get musicPickerSpotifyAttribution => 'Music data provided by Spotify';

  @override
  String get placePickerScreenTitle => 'Add Place';

  @override
  String get placePickerSearchHint => 'Search places…';

  @override
  String get placePickerEmpty => 'Search for a place to add.';

  @override
  String get placePickerAppleAttribution => 'Search by Apple Maps';

  @override
  String get placePickerScopeDomestic => 'Korea';

  @override
  String get placePickerScopeOverseas => 'Overseas';

  @override
  String get onboardingGetStarted => 'Get Started';

  @override
  String get onboardingContinueWithApple => 'Continue with Apple';

  @override
  String get onboardingContinueWithGoogle => 'Continue with Google';

  @override
  String get onboardingContinueWithKakao => 'Continue with Kakao';

  @override
  String get onboardingAgreementContinue => 'Continue';

  @override
  String get authErrorNetwork => 'Check your connection and try again.';

  @override
  String get authErrorGeneric => 'Sign in failed. Please try again.';

  @override
  String get actionContinue => 'Continue';

  @override
  String get sceneDetailDeleteMessage =>
      'All moments in this scene will also be removed.';

  @override
  String get sceneDetailDeleteFailedToast => 'Failed to delete scene.';

  @override
  String get sceneDetailReorderSaveFailedToast => 'Failed to save order.';

  @override
  String get profileSetupTagline =>
      'Add a photo and your name\nso your person can recognize you.';

  @override
  String profileSetupNameHint(int max) {
    return 'Your name (max $max)';
  }

  @override
  String get profileSetupSaveFailedToast => 'Failed to save profile.';

  @override
  String get pairingTagline =>
      'Share your invite code or\nenter your person\'s code to pair.';

  @override
  String get pairingYourInviteCode => 'Your invite code';

  @override
  String get pairingEnterPersonCodeButton => 'Enter person\'s code';

  @override
  String get pairingActionCopy => 'Copy';

  @override
  String get pairingActionShare => 'Share';

  @override
  String get pairingEnterCodeHint => 'Your person\'s code';

  @override
  String get pairingEnterCodeAction => 'Pair';

  @override
  String get pairingCodeCopiedToast => 'Code copied';

  @override
  String pairingShareMessage(String link, String code) {
    return 'Let\'s collect our scenes together on Scenes 💞\n\nDownload the app → $link\nInvite code: $code';
  }

  @override
  String get pairingFailedToast => 'Failed to pair. Please try again.';

  @override
  String get pairingErrorInvalidCode => 'Invalid code.';

  @override
  String get pairingErrorAlreadyUsed => 'This code has already been used.';

  @override
  String get pairingErrorExpired => 'This code has expired.';

  @override
  String get pairingErrorOwnCode => 'You can\'t use your own code.';

  @override
  String get pairingErrorInviterUnavailable =>
      'This code is no longer available.';

  @override
  String get pairingErrorAlreadyPaired =>
      'You\'re already paired with someone.';

  @override
  String get pairingCodeLoadError => 'Could not load code. Tap to retry.';

  @override
  String get pairingCodeExpiredBadge => 'Expired';

  @override
  String pairingCodeExpiresHours(int hours, int minutes) {
    return 'Expires in ${hours}h ${minutes}m';
  }

  @override
  String pairingCodeExpiresMinutes(int minutes) {
    return 'Expires in ${minutes}m';
  }

  @override
  String pairingCodeExpiresSeconds(int seconds) {
    return 'Expires in ${seconds}s';
  }

  @override
  String get pairingSignOutConfirmMessage =>
      'You will need to sign in again to use Scenes.';

  @override
  String get subscriptionUnavailableError =>
      'Subscription is not available right now.';

  @override
  String get subscriptionGenericError => 'Purchase failed. Please try again.';

  @override
  String get sceneDetailPlay => 'Play scene';

  @override
  String get sceneDetailEmptyMedia =>
      'Fill this Scene with moments that matter.';

  @override
  String profileNarrative(
    String partnerA,
    String partnerB,
    String date,
    int count,
  ) {
    return 'Since $date, we have captured $count Scenes together.';
  }

  @override
  String coupleScenesCount(int count) {
    return '$count Scenes';
  }

  @override
  String notiPromptTitleWithName(String name) {
    return 'Don\'t miss\n$name\'s updates';
  }

  @override
  String get notiPromptTitleNoName => 'Don\'t miss\na single update';

  @override
  String notiPromptBodyWithName(String name) {
    return 'Get notified when $name adds scenes,\nmoments, or reacts to yours.';
  }

  @override
  String get notiPromptBodyNoName =>
      'Get notified when your person adds scenes,\nmoments, or reacts to yours.';

  @override
  String get notiPromptAllow => 'Allow notifications';

  @override
  String get notiPromptSkip => 'Maybe later';

  @override
  String addMediaCapacityLabel(int count, int limit) {
    return 'Moments $count/$limit';
  }

  @override
  String get addMediaDateToday => 'Today';

  @override
  String addMediaToastSceneFull(int limit) {
    return 'Scene is full ($limit).';
  }

  @override
  String addMediaToastFreeLimit(int limit) {
    return 'Free scenes hold up to $limit moments. Upgrade for more.';
  }

  @override
  String get hdBannerBenefitMedia => 'Unlock films, music, and places.';

  @override
  String get hdBannerBenefitMoments => 'Up to 100 moments in every scene.';

  @override
  String get subscriptionTagline => 'Make our scenes more vivid';

  @override
  String get subscriptionBannerTaglineActive => 'Making our scenes more vivid.';

  @override
  String get subscriptionBannerLearnMore => 'Learn more';

  @override
  String get shareCardTagline => 'Show friends our story.';

  @override
  String get shareCardSetPrompt => 'Set a nickname to share';

  @override
  String get shareAddressLabel => 'Your address';

  @override
  String get shareIdSetNeeded => 'Set your ID';

  @override
  String get shareIdChange => 'Change ID';

  @override
  String get shareLinkCopied => 'Link copied';

  @override
  String get shareNicknameSheetDesc => 'This becomes your shared page address.';

  @override
  String get shareNicknameAvailable => 'Available';

  @override
  String get shareNicknameTaken => 'Already taken';

  @override
  String get shareNicknameInvalid => '3–30 letters, numbers, or hyphens';

  @override
  String get shareNicknameChangeWarning =>
      'Changing this breaks your current link.';

  @override
  String get shareNicknameSaveFailed => 'Couldn\'t save. Please try again.';

  @override
  String get subscriptionFeaturePairTitle => 'One for two';

  @override
  String get subscriptionFeaturePairDesc =>
      'When just one of you subscribes, Scenes HD unlocks for both.';

  @override
  String get subscriptionFeatureMomentTypesTitle => 'More Moment Types';

  @override
  String get subscriptionFeatureMomentTypesDesc =>
      'Add films, music, and places to your scenes.';

  @override
  String get subscriptionFeatureMomentsPerSceneTitle =>
      'More Moments per Scene';

  @override
  String get subscriptionFeatureMomentsPerSceneDesc =>
      'Capture up to 100 moments in every scene, instead of 30.';

  @override
  String get subscriptionFeatureReactionCommentsTitle => 'Reaction Comments';

  @override
  String get subscriptionFeatureReactionCommentsDesc =>
      'Leave a personal note alongside any reaction.';

  @override
  String get subscriptionFeatureReorderTitle => 'Reorder Scenes & Moments';

  @override
  String get subscriptionFeatureReorderDesc =>
      'Arrange scenes and moments in any order you like.';

  @override
  String get subscriptionFeatureFiltersTitle => 'Playback Filters';

  @override
  String get subscriptionFeatureFiltersDesc =>
      'Choose from a range of film looks for your playback.';

  @override
  String get subscriptionFeatureTemplatesTitle => 'More Share Templates';

  @override
  String get subscriptionFeatureTemplatesDesc =>
      'Share your scenes with a growing collection of video templates.';

  @override
  String get subscriptionFooterPair =>
      'Only one of you needs to subscribe — Scenes HD applies to both of you.';

  @override
  String subscriptionFooterPlan(String price) {
    return 'Scenes HD is a monthly auto-renewing subscription at $price/month, with a 7-day free trial for new subscribers.';
  }

  @override
  String subscriptionFooterTrialConversion(String price) {
    return 'Your 7-day free trial automatically converts to a paid monthly subscription at $price when the trial ends. To avoid being charged, cancel at least 24 hours before your trial ends.';
  }

  @override
  String get subscriptionFooterTrialEligibility =>
      'The free trial is available to new subscribers only. If you have previously subscribed with this Apple ID (including through Family Sharing), you may not be eligible for another free trial.';

  @override
  String get subscriptionFooterCharge =>
      'Payment will be charged to your Apple ID account at confirmation of purchase.';

  @override
  String subscriptionFooterRenewal(String price) {
    return 'Your subscription automatically renews unless auto-renew is turned off at least 24 hours before the end of the current period. Your account will be charged for renewal within 24 hours prior to the end of the current period at $price/month.';
  }

  @override
  String get subscriptionFooterManage =>
      'You can manage or cancel your subscription in your App Store account settings after purchase. Any unused portion of a free trial will be forfeited when you start a paid subscription.';

  @override
  String subscriptionCtaSubscribe(String price) {
    return 'Subscribe for $price/mo';
  }

  @override
  String get subscriptionCtaManage => 'Manage Subscription';

  @override
  String subscriptionCtaThanks(String name) {
    return 'Thanks to $name';
  }

  @override
  String get subscriptionFreeBadge => 'Free for 7 days';

  @override
  String get subscriptionLinkPrivacy => 'Privacy Policy';

  @override
  String get subscriptionLinkRestore => 'Restore';

  @override
  String get subscriptionLinkTerms => 'Terms of Service';

  @override
  String get subscriptionToastWelcome => 'Welcome to Scenes HD.';

  @override
  String get subscriptionToastRestored => 'Subscription restored.';

  @override
  String get subscriptionToastNothingToRestore => 'No purchases to restore.';

  @override
  String get notificationsBannerTitle => 'Turn on notifications';

  @override
  String notificationsBannerBodyWithName(String name) {
    return 'Enable in Settings to receive $name\'s activity and updates.';
  }

  @override
  String get notificationsBannerBodyNoName =>
      'Enable in Settings to receive your partner\'s activity and updates.';

  @override
  String get notificationsLoadError => 'Could not load preferences.';

  @override
  String get notificationsPartnerActivityLabel => 'Partner activity';

  @override
  String get notificationsPartnerActivityDesc =>
      'When your partner adds scenes, moments, or likes yours.';

  @override
  String get notificationsAppNewsLabel => 'App news';

  @override
  String get notificationsAppNewsDesc =>
      'Updates about new features and announcements.';

  @override
  String get signOutConfirmTitle => 'Sign Out?';

  @override
  String get signOutConfirmMessage =>
      'You will need to sign in again to use Scenes.';

  @override
  String get signOutConfirmAction => 'Sign Out';

  @override
  String get disconnectConfirmTitle => 'Disconnect?';

  @override
  String get disconnectConfirmMessage =>
      'You and your person will be unpaired.';

  @override
  String get disconnectConfirmNotice =>
      'All data tied to this relationship (scenes, photos, films, music, places, reactions, etc.) will be permanently deleted 6 months later.';

  @override
  String get disconnectSignTitle => 'Final check';

  @override
  String get disconnectSignHeading => 'Type UNPAIR to confirm the disconnect.';

  @override
  String get disconnectSignPhrase => 'UNPAIR';

  @override
  String get disconnectSignInputHint => 'Type UNPAIR';

  @override
  String get disconnectConfirmAction => 'Disconnect';

  @override
  String get disconnectFailedToast => 'Failed to disconnect.';

  @override
  String get deleteAccountConfirmTitle => 'Delete account?';

  @override
  String get deleteAccountConfirmMessage => 'This cannot be undone.';

  @override
  String get deleteAccountConfirmNotice =>
      'Your account and all relationship data (scenes, photos, films, music, places, reactions, etc.) will be permanently deleted right away. Your partner will lose access too.';

  @override
  String get deleteAccountSignTitle => 'Final check';

  @override
  String get deleteAccountSignHeading =>
      'Type DELETE to permanently remove your account.';

  @override
  String get deleteAccountSignPhrase => 'DELETE';

  @override
  String get deleteAccountSignInputHint => 'Type DELETE';

  @override
  String get deleteAccountSignAction => 'Delete forever';

  @override
  String get deleteAccountSignDeleting => 'Deleting…';

  @override
  String get deleteAccountConfirmAction => 'Delete';

  @override
  String get deleteAccountFailedToast => 'Failed to delete account.';

  @override
  String get deleteAccountActiveSubTitle => 'Active subscription';

  @override
  String get deleteAccountActiveSubMessage =>
      'Cancel your subscription in System Settings to stop being charged. Deleting your account here does not cancel it.';

  @override
  String get deleteAccountActiveSubConfirm => 'Delete anyway';

  @override
  String get deleteAccountActiveSubCancel => 'Manage subscription';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get settingsAppVersion => 'Version';

  @override
  String get creditMoreButton => 'More';

  @override
  String get settingsAppLock => 'App Lock';

  @override
  String get lockTitleSetup => 'Set Up Lock';

  @override
  String get lockTitleChange => 'Change PIN';

  @override
  String get lockTitleVerify => 'Confirm PIN';

  @override
  String get lockEnterCurrent => 'Enter your current PIN';

  @override
  String get lockEnterCurrentDesc => 'We\'ll verify it before continuing.';

  @override
  String get lockEnterNew => 'Enter a new 4-digit PIN';

  @override
  String get lockEnterNewDesc => 'You\'ll use this to unlock the app.';

  @override
  String get lockConfirmNew => 'Confirm your new PIN';

  @override
  String get lockConfirmNewDesc => 'Re-enter the same PIN.';

  @override
  String get lockSettingsHeader => 'App Lock';

  @override
  String get lockSettingsEnabledDesc => 'App Lock is on.';

  @override
  String get lockSettingsDisabledDesc => 'Require a PIN to open the app.';

  @override
  String get lockSetUpButton => 'Set Up PIN';

  @override
  String get lockChangePinButton => 'Change PIN';

  @override
  String get lockDisableButton => 'Turn Off App Lock';

  @override
  String get lockBiometricToggle => 'Unlock with Face ID / Touch ID';

  @override
  String get lockBiometricUnavailable =>
      'Biometric authentication is not available on this device.';

  @override
  String get lockRecoveryNotice =>
      'If you forget your PIN, sign in again to reset App Lock.';

  @override
  String get lockChallengeTitle => 'Enter PIN';

  @override
  String get lockBiometricPrompt => 'Unlock Scenes';

  @override
  String get lockForgotPin => 'Forgot PIN?';

  @override
  String get lockForgotConfirmTitle => 'Sign Out?';

  @override
  String get lockForgotConfirmBody =>
      'Signing out will turn off App Lock.\nAfter signing in again, you\'ll need to set it up from Settings.';

  @override
  String get lockForgotConfirmAction => 'Sign Out';

  @override
  String get lockDisableConfirmTitle => 'Turn Off App Lock?';

  @override
  String get lockDisableConfirmBody =>
      'PIN and biometric settings will be cleared.';

  @override
  String get lockDisableConfirmAction => 'Turn Off';
}
