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

  /// A11y label for the right transport button (opens rewind screen across all scenes).
  ///
  /// In en, this message translates to:
  /// **'Rewind'**
  String get transportRecap;

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
  /// **'Edit scene'**
  String get sceneDetailEdit;

  /// Action label that opens a sheet to set the date for every moment in this scene.
  ///
  /// In en, this message translates to:
  /// **'Edit date'**
  String get sceneDetailEditDate;

  /// Title shown on the bulk-edit date picker sheet.
  ///
  /// In en, this message translates to:
  /// **'Edit date'**
  String get sceneDetailEditDateSheetTitle;

  /// Helper text shown above the bulk-edit date picker explaining its scope.
  ///
  /// In en, this message translates to:
  /// **'Sets the date for every moment in this scene.'**
  String get sceneDetailEditDateSheetInfo;

  /// Toast shown when the bulk-edit moment date call fails.
  ///
  /// In en, this message translates to:
  /// **'Failed to update dates.'**
  String get sceneDetailEditDateFailedToast;

  /// No description provided for @actionDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get actionDelete;

  /// No description provided for @actionRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get actionRemove;

  /// No description provided for @reactionPickerUpdate.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get reactionPickerUpdate;

  /// No description provided for @reactionPickerCommentHint.
  ///
  /// In en, this message translates to:
  /// **'Leave a comment (optional)'**
  String get reactionPickerCommentHint;

  /// No description provided for @reactionPickerHdUpsellSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add a comment to your reaction.'**
  String get reactionPickerHdUpsellSubtitle;

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

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @languageScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageScreenTitle;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageKorean.
  ///
  /// In en, this message translates to:
  /// **'한국어'**
  String get languageKorean;

  /// Option to follow the device's locale.
  ///
  /// In en, this message translates to:
  /// **'Use device language'**
  String get languageSystem;

  /// No description provided for @themeScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get themeScreenTitle;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// Option to follow the device's appearance setting.
  ///
  /// In en, this message translates to:
  /// **'Use device theme'**
  String get themeSystem;

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
  /// **'Sign Out'**
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

  /// No description provided for @actionSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get actionSave;

  /// No description provided for @imageCropperTitle.
  ///
  /// In en, this message translates to:
  /// **'Crop'**
  String get imageCropperTitle;

  /// No description provided for @editProfileNameHint.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get editProfileNameHint;

  /// No description provided for @editProfileSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Save failed.'**
  String get editProfileSaveFailed;

  /// No description provided for @createSceneTitleHint.
  ///
  /// In en, this message translates to:
  /// **'Scene title'**
  String get createSceneTitleHint;

  /// No description provided for @createSceneCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get createSceneCreate;

  /// No description provided for @createSceneSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save scene.'**
  String get createSceneSaveFailed;

  /// No description provided for @datePickerConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get datePickerConfirm;

  /// No description provided for @mediaLabelPhoto.
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get mediaLabelPhoto;

  /// No description provided for @mediaLabelFilm.
  ///
  /// In en, this message translates to:
  /// **'Film'**
  String get mediaLabelFilm;

  /// No description provided for @mediaLabelMusic.
  ///
  /// In en, this message translates to:
  /// **'Music'**
  String get mediaLabelMusic;

  /// No description provided for @mediaLabelPlace.
  ///
  /// In en, this message translates to:
  /// **'Place'**
  String get mediaLabelPlace;

  /// No description provided for @recapEmptyPhotos.
  ///
  /// In en, this message translates to:
  /// **'No photos to rewind yet.'**
  String get recapEmptyPhotos;

  /// No description provided for @recapEmptyFilms.
  ///
  /// In en, this message translates to:
  /// **'No films to rewind yet.'**
  String get recapEmptyFilms;

  /// No description provided for @recapEmptyMusic.
  ///
  /// In en, this message translates to:
  /// **'No songs to rewind yet.'**
  String get recapEmptyMusic;

  /// No description provided for @recapEmptyPlaces.
  ///
  /// In en, this message translates to:
  /// **'No places to rewind yet.'**
  String get recapEmptyPlaces;

  /// No description provided for @recapFilteredEmptyPhotos.
  ///
  /// In en, this message translates to:
  /// **'No photos in selected scenes.'**
  String get recapFilteredEmptyPhotos;

  /// No description provided for @recapFilteredEmptyFilms.
  ///
  /// In en, this message translates to:
  /// **'No films in selected scenes.'**
  String get recapFilteredEmptyFilms;

  /// No description provided for @recapFilteredEmptyMusic.
  ///
  /// In en, this message translates to:
  /// **'No songs in selected scenes.'**
  String get recapFilteredEmptyMusic;

  /// No description provided for @recapFilteredEmptyPlaces.
  ///
  /// In en, this message translates to:
  /// **'No places in selected scenes.'**
  String get recapFilteredEmptyPlaces;

  /// No description provided for @reactionSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save reaction.'**
  String get reactionSaveFailed;

  /// No description provided for @reactionRemoveFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to remove reaction.'**
  String get reactionRemoveFailed;

  /// No description provided for @recapNavPrevious.
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get recapNavPrevious;

  /// No description provided for @recapNavNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get recapNavNext;

  /// No description provided for @recapNavPreviousPlace.
  ///
  /// In en, this message translates to:
  /// **'Previous place'**
  String get recapNavPreviousPlace;

  /// No description provided for @recapNavNextPlace.
  ///
  /// In en, this message translates to:
  /// **'Next place'**
  String get recapNavNextPlace;

  /// No description provided for @recapTicketReleased.
  ///
  /// In en, this message translates to:
  /// **'Released'**
  String get recapTicketReleased;

  /// No description provided for @recapTicketRuntime.
  ///
  /// In en, this message translates to:
  /// **'Runtime'**
  String get recapTicketRuntime;

  /// No description provided for @recapTicketWatched.
  ///
  /// In en, this message translates to:
  /// **'Watched'**
  String get recapTicketWatched;

  /// Movie runtime — short form, no space (film ticket card).
  ///
  /// In en, this message translates to:
  /// **'{minutes}min'**
  String runtimeMinutesValue(int minutes);

  /// Movie runtime — with space (content detail overlay).
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String runtimeMinutesValueSpaced(int minutes);

  /// No description provided for @contentDetailFilmMovie.
  ///
  /// In en, this message translates to:
  /// **'Movie'**
  String get contentDetailFilmMovie;

  /// No description provided for @contentDetailFilmTvSeries.
  ///
  /// In en, this message translates to:
  /// **'TV Series'**
  String get contentDetailFilmTvSeries;

  /// No description provided for @contentDetailMusicTrack.
  ///
  /// In en, this message translates to:
  /// **'Track'**
  String get contentDetailMusicTrack;

  /// No description provided for @contentDetailMusicAlbum.
  ///
  /// In en, this message translates to:
  /// **'Album'**
  String get contentDetailMusicAlbum;

  /// No description provided for @contentDetailUpdateDateFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to update date.'**
  String get contentDetailUpdateDateFailed;

  /// No description provided for @contentDetailDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'It will be removed from this scene.'**
  String get contentDetailDeleteMessage;

  /// No description provided for @contentDetailDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete.'**
  String get contentDetailDeleteFailed;

  /// No description provided for @actionApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get actionApply;

  /// No description provided for @uploadCancelDialogMessage.
  ///
  /// In en, this message translates to:
  /// **'Photos already uploaded will stay.'**
  String get uploadCancelDialogMessage;

  /// No description provided for @uploadCancelKeepUploading.
  ///
  /// In en, this message translates to:
  /// **'Keep uploading'**
  String get uploadCancelKeepUploading;

  /// No description provided for @filterScenesAll.
  ///
  /// In en, this message translates to:
  /// **'All scenes'**
  String get filterScenesAll;

  /// No description provided for @playSceneAction.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get playSceneAction;

  /// No description provided for @playSceneStop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get playSceneStop;

  /// No description provided for @playSceneNoMomentsToast.
  ///
  /// In en, this message translates to:
  /// **'No moments to play.'**
  String get playSceneNoMomentsToast;

  /// No description provided for @playSceneLoadingPreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing the scene…'**
  String get playSceneLoadingPreparing;

  /// No description provided for @playSceneFilterNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get playSceneFilterNormal;

  /// No description provided for @playSceneFilterVintage.
  ///
  /// In en, this message translates to:
  /// **'Vintage'**
  String get playSceneFilterVintage;

  /// No description provided for @playSceneFilterCinema.
  ///
  /// In en, this message translates to:
  /// **'Cinema'**
  String get playSceneFilterCinema;

  /// No description provided for @playSceneFilterMono.
  ///
  /// In en, this message translates to:
  /// **'Mono'**
  String get playSceneFilterMono;

  /// No description provided for @playSceneSelectMoments.
  ///
  /// In en, this message translates to:
  /// **'Select Moments'**
  String get playSceneSelectMoments;

  /// Count of Moments shown under the Select Moments row in the Playback sheet.
  ///
  /// In en, this message translates to:
  /// **'{count} moments'**
  String playSceneMomentsCount(int count);

  /// No description provided for @playSceneShuffle.
  ///
  /// In en, this message translates to:
  /// **'Shuffle'**
  String get playSceneShuffle;

  /// No description provided for @playSceneHdUpsellSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Apply film looks to your playback.'**
  String get playSceneHdUpsellSubtitle;

  /// No description provided for @playSceneShareFailedToast.
  ///
  /// In en, this message translates to:
  /// **'Share failed.'**
  String get playSceneShareFailedToast;

  /// No description provided for @playScenePhotoPermissionToast.
  ///
  /// In en, this message translates to:
  /// **'Photo permission required.'**
  String get playScenePhotoPermissionToast;

  /// No description provided for @playSceneSavedToPhotosToast.
  ///
  /// In en, this message translates to:
  /// **'Saved to Photos'**
  String get playSceneSavedToPhotosToast;

  /// No description provided for @playSceneInstagramMissingToast.
  ///
  /// In en, this message translates to:
  /// **'Instagram is not installed.'**
  String get playSceneInstagramMissingToast;

  /// No description provided for @playSceneShareStory.
  ///
  /// In en, this message translates to:
  /// **'Story'**
  String get playSceneShareStory;

  /// No description provided for @playSceneShareMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get playSceneShareMore;

  /// No description provided for @photoPickerScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Photos'**
  String get photoPickerScreenTitle;

  /// No description provided for @photoPickerEmpty.
  ///
  /// In en, this message translates to:
  /// **'No photos found'**
  String get photoPickerEmpty;

  /// No description provided for @photoPickerAllPhotos.
  ///
  /// In en, this message translates to:
  /// **'All Photos'**
  String get photoPickerAllPhotos;

  /// Toast when the user hits the per-upload batch cap.
  ///
  /// In en, this message translates to:
  /// **'Up to {limit} photos per upload.'**
  String photoPickerBatchCapToast(int limit);

  /// No description provided for @photoPickerSceneCapToast.
  ///
  /// In en, this message translates to:
  /// **'Scene\'s upload limit reached.'**
  String get photoPickerSceneCapToast;

  /// No description provided for @pickerSearchFailed.
  ///
  /// In en, this message translates to:
  /// **'Search failed. Please try again.'**
  String get pickerSearchFailed;

  /// No description provided for @pickerNoResults.
  ///
  /// In en, this message translates to:
  /// **'No results found.'**
  String get pickerNoResults;

  /// No description provided for @filmPickerScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Film'**
  String get filmPickerScreenTitle;

  /// No description provided for @filmPickerSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search films…'**
  String get filmPickerSearchHint;

  /// No description provided for @filmPickerEmpty.
  ///
  /// In en, this message translates to:
  /// **'Search for a film to add.'**
  String get filmPickerEmpty;

  /// No description provided for @filmPickerTmdbAttribution.
  ///
  /// In en, this message translates to:
  /// **'Movie data provided by TMDB'**
  String get filmPickerTmdbAttribution;

  /// No description provided for @musicPickerScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Music'**
  String get musicPickerScreenTitle;

  /// No description provided for @musicPickerSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search music…'**
  String get musicPickerSearchHint;

  /// No description provided for @musicPickerEmpty.
  ///
  /// In en, this message translates to:
  /// **'Search for music to add.'**
  String get musicPickerEmpty;

  /// No description provided for @musicPickerSpotifyAttribution.
  ///
  /// In en, this message translates to:
  /// **'Music data provided by Spotify'**
  String get musicPickerSpotifyAttribution;

  /// No description provided for @placePickerScreenTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Place'**
  String get placePickerScreenTitle;

  /// No description provided for @placePickerSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search places…'**
  String get placePickerSearchHint;

  /// No description provided for @placePickerEmpty.
  ///
  /// In en, this message translates to:
  /// **'Search for a place to add.'**
  String get placePickerEmpty;

  /// No description provided for @placePickerAppleAttribution.
  ///
  /// In en, this message translates to:
  /// **'Search by Apple Maps'**
  String get placePickerAppleAttribution;

  /// No description provided for @placePickerScopeDomestic.
  ///
  /// In en, this message translates to:
  /// **'Korea'**
  String get placePickerScopeDomestic;

  /// No description provided for @placePickerScopeOverseas.
  ///
  /// In en, this message translates to:
  /// **'Overseas'**
  String get placePickerScopeOverseas;

  /// No description provided for @onboardingGetStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get onboardingGetStarted;

  /// No description provided for @onboardingContinueWithApple.
  ///
  /// In en, this message translates to:
  /// **'Continue with Apple'**
  String get onboardingContinueWithApple;

  /// No description provided for @onboardingContinueWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get onboardingContinueWithGoogle;

  /// No description provided for @onboardingContinueWithKakao.
  ///
  /// In en, this message translates to:
  /// **'Continue with Kakao'**
  String get onboardingContinueWithKakao;

  /// No description provided for @onboardingAgreementContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get onboardingAgreementContinue;

  /// No description provided for @authErrorNetwork.
  ///
  /// In en, this message translates to:
  /// **'Check your connection and try again.'**
  String get authErrorNetwork;

  /// No description provided for @authErrorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Sign in failed. Please try again.'**
  String get authErrorGeneric;

  /// No description provided for @actionContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get actionContinue;

  /// No description provided for @sceneDetailDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'All moments in this scene will also be removed.'**
  String get sceneDetailDeleteMessage;

  /// No description provided for @sceneDetailDeleteFailedToast.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete scene.'**
  String get sceneDetailDeleteFailedToast;

  /// No description provided for @sceneDetailReorderSaveFailedToast.
  ///
  /// In en, this message translates to:
  /// **'Failed to save order.'**
  String get sceneDetailReorderSaveFailedToast;

  /// No description provided for @profileSetupTagline.
  ///
  /// In en, this message translates to:
  /// **'Add a photo and your name\nso your person can recognize you.'**
  String get profileSetupTagline;

  /// No description provided for @profileSetupNameHint.
  ///
  /// In en, this message translates to:
  /// **'Your name (max {max})'**
  String profileSetupNameHint(int max);

  /// No description provided for @profileSetupSaveFailedToast.
  ///
  /// In en, this message translates to:
  /// **'Failed to save profile.'**
  String get profileSetupSaveFailedToast;

  /// No description provided for @pairingTagline.
  ///
  /// In en, this message translates to:
  /// **'Share your invite code or\nenter your person\'s code to pair.'**
  String get pairingTagline;

  /// No description provided for @pairingYourInviteCode.
  ///
  /// In en, this message translates to:
  /// **'Your invite code'**
  String get pairingYourInviteCode;

  /// No description provided for @pairingEnterPersonCodeButton.
  ///
  /// In en, this message translates to:
  /// **'Enter person\'s code'**
  String get pairingEnterPersonCodeButton;

  /// No description provided for @pairingActionCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get pairingActionCopy;

  /// No description provided for @pairingActionShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get pairingActionShare;

  /// No description provided for @pairingEnterCodeHint.
  ///
  /// In en, this message translates to:
  /// **'Your person\'s code'**
  String get pairingEnterCodeHint;

  /// No description provided for @pairingEnterCodeAction.
  ///
  /// In en, this message translates to:
  /// **'Pair'**
  String get pairingEnterCodeAction;

  /// No description provided for @pairingCodeCopiedToast.
  ///
  /// In en, this message translates to:
  /// **'Code copied'**
  String get pairingCodeCopiedToast;

  /// No description provided for @pairingShareMessage.
  ///
  /// In en, this message translates to:
  /// **'Let\'s collect our scenes together on Scenes 💞\n\nDownload the app → {link}\nInvite code: {code}'**
  String pairingShareMessage(String link, String code);

  /// No description provided for @pairingFailedToast.
  ///
  /// In en, this message translates to:
  /// **'Failed to pair. Please try again.'**
  String get pairingFailedToast;

  /// No description provided for @pairingErrorInvalidCode.
  ///
  /// In en, this message translates to:
  /// **'Invalid code.'**
  String get pairingErrorInvalidCode;

  /// No description provided for @pairingErrorAlreadyUsed.
  ///
  /// In en, this message translates to:
  /// **'This code has already been used.'**
  String get pairingErrorAlreadyUsed;

  /// No description provided for @pairingErrorExpired.
  ///
  /// In en, this message translates to:
  /// **'This code has expired.'**
  String get pairingErrorExpired;

  /// No description provided for @pairingErrorOwnCode.
  ///
  /// In en, this message translates to:
  /// **'You can\'t use your own code.'**
  String get pairingErrorOwnCode;

  /// No description provided for @pairingErrorInviterUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This code is no longer available.'**
  String get pairingErrorInviterUnavailable;

  /// No description provided for @pairingErrorAlreadyPaired.
  ///
  /// In en, this message translates to:
  /// **'You\'re already paired with someone.'**
  String get pairingErrorAlreadyPaired;

  /// No description provided for @pairingCodeLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load code. Tap to retry.'**
  String get pairingCodeLoadError;

  /// No description provided for @pairingCodeExpiredBadge.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get pairingCodeExpiredBadge;

  /// No description provided for @pairingCodeExpiresHours.
  ///
  /// In en, this message translates to:
  /// **'Expires in {hours}h {minutes}m'**
  String pairingCodeExpiresHours(int hours, int minutes);

  /// No description provided for @pairingCodeExpiresMinutes.
  ///
  /// In en, this message translates to:
  /// **'Expires in {minutes}m'**
  String pairingCodeExpiresMinutes(int minutes);

  /// No description provided for @pairingCodeExpiresSeconds.
  ///
  /// In en, this message translates to:
  /// **'Expires in {seconds}s'**
  String pairingCodeExpiresSeconds(int seconds);

  /// No description provided for @pairingSignOutConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'You will need to sign in again to use Scenes.'**
  String get pairingSignOutConfirmMessage;

  /// No description provided for @subscriptionUnavailableError.
  ///
  /// In en, this message translates to:
  /// **'Subscription is not available right now.'**
  String get subscriptionUnavailableError;

  /// No description provided for @subscriptionGenericError.
  ///
  /// In en, this message translates to:
  /// **'Purchase failed. Please try again.'**
  String get subscriptionGenericError;

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

  /// No description provided for @addMediaDateToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get addMediaDateToday;

  /// Toast shown when the current scene already has the HD-tier maximum number of moments.
  ///
  /// In en, this message translates to:
  /// **'Scene is full ({limit}).'**
  String addMediaToastSceneFull(int limit);

  /// Toast shown when a free-tier scene has reached its moment limit.
  ///
  /// In en, this message translates to:
  /// **'Free scenes hold up to {limit} moments. Upgrade for more.'**
  String addMediaToastFreeLimit(int limit);

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

  /// No description provided for @subscriptionTagline.
  ///
  /// In en, this message translates to:
  /// **'Make our scenes more vivid'**
  String get subscriptionTagline;

  /// No description provided for @subscriptionBannerTaglineActive.
  ///
  /// In en, this message translates to:
  /// **'Making our scenes more vivid.'**
  String get subscriptionBannerTaglineActive;

  /// No description provided for @subscriptionBannerLearnMore.
  ///
  /// In en, this message translates to:
  /// **'Learn more'**
  String get subscriptionBannerLearnMore;

  /// No description provided for @subscriptionFeaturePairTitle.
  ///
  /// In en, this message translates to:
  /// **'One for two'**
  String get subscriptionFeaturePairTitle;

  /// No description provided for @subscriptionFeaturePairDesc.
  ///
  /// In en, this message translates to:
  /// **'When just one of you subscribes, Scenes HD unlocks for both.'**
  String get subscriptionFeaturePairDesc;

  /// No description provided for @subscriptionFeatureMomentTypesTitle.
  ///
  /// In en, this message translates to:
  /// **'More Moment Types'**
  String get subscriptionFeatureMomentTypesTitle;

  /// No description provided for @subscriptionFeatureMomentTypesDesc.
  ///
  /// In en, this message translates to:
  /// **'Add films, music, and places to your scenes.'**
  String get subscriptionFeatureMomentTypesDesc;

  /// No description provided for @subscriptionFeatureMomentsPerSceneTitle.
  ///
  /// In en, this message translates to:
  /// **'More Moments per Scene'**
  String get subscriptionFeatureMomentsPerSceneTitle;

  /// No description provided for @subscriptionFeatureMomentsPerSceneDesc.
  ///
  /// In en, this message translates to:
  /// **'Capture up to 100 moments in every scene, instead of 30.'**
  String get subscriptionFeatureMomentsPerSceneDesc;

  /// No description provided for @subscriptionFeatureReactionCommentsTitle.
  ///
  /// In en, this message translates to:
  /// **'Reaction Comments'**
  String get subscriptionFeatureReactionCommentsTitle;

  /// No description provided for @subscriptionFeatureReactionCommentsDesc.
  ///
  /// In en, this message translates to:
  /// **'Leave a personal note alongside any reaction.'**
  String get subscriptionFeatureReactionCommentsDesc;

  /// No description provided for @subscriptionFeatureReorderTitle.
  ///
  /// In en, this message translates to:
  /// **'Reorder Scenes & Moments'**
  String get subscriptionFeatureReorderTitle;

  /// No description provided for @subscriptionFeatureReorderDesc.
  ///
  /// In en, this message translates to:
  /// **'Arrange scenes and moments in any order you like.'**
  String get subscriptionFeatureReorderDesc;

  /// No description provided for @subscriptionFeatureFiltersTitle.
  ///
  /// In en, this message translates to:
  /// **'Playback Filters'**
  String get subscriptionFeatureFiltersTitle;

  /// No description provided for @subscriptionFeatureFiltersDesc.
  ///
  /// In en, this message translates to:
  /// **'Choose from a range of film looks for your playback.'**
  String get subscriptionFeatureFiltersDesc;

  /// No description provided for @subscriptionFeatureTemplatesTitle.
  ///
  /// In en, this message translates to:
  /// **'More Share Templates'**
  String get subscriptionFeatureTemplatesTitle;

  /// No description provided for @subscriptionFeatureTemplatesDesc.
  ///
  /// In en, this message translates to:
  /// **'Share your scenes with a growing collection of video templates.'**
  String get subscriptionFeatureTemplatesDesc;

  /// No description provided for @subscriptionFooterPair.
  ///
  /// In en, this message translates to:
  /// **'Only one of you needs to subscribe — Scenes HD applies to both of you.'**
  String get subscriptionFooterPair;

  /// No description provided for @subscriptionFooterPlan.
  ///
  /// In en, this message translates to:
  /// **'Scenes HD is a monthly auto-renewing subscription at {price}/month, with a 7-day free trial for new subscribers.'**
  String subscriptionFooterPlan(String price);

  /// No description provided for @subscriptionFooterTrialConversion.
  ///
  /// In en, this message translates to:
  /// **'Your 7-day free trial automatically converts to a paid monthly subscription at {price} when the trial ends. To avoid being charged, cancel at least 24 hours before your trial ends.'**
  String subscriptionFooterTrialConversion(String price);

  /// No description provided for @subscriptionFooterTrialEligibility.
  ///
  /// In en, this message translates to:
  /// **'The free trial is available to new subscribers only. If you have previously subscribed with this Apple ID (including through Family Sharing), you may not be eligible for another free trial.'**
  String get subscriptionFooterTrialEligibility;

  /// No description provided for @subscriptionFooterCharge.
  ///
  /// In en, this message translates to:
  /// **'Payment will be charged to your Apple ID account at confirmation of purchase.'**
  String get subscriptionFooterCharge;

  /// No description provided for @subscriptionFooterRenewal.
  ///
  /// In en, this message translates to:
  /// **'Your subscription automatically renews unless auto-renew is turned off at least 24 hours before the end of the current period. Your account will be charged for renewal within 24 hours prior to the end of the current period at {price}/month.'**
  String subscriptionFooterRenewal(String price);

  /// No description provided for @subscriptionFooterManage.
  ///
  /// In en, this message translates to:
  /// **'You can manage or cancel your subscription in your App Store account settings after purchase. Any unused portion of a free trial will be forfeited when you start a paid subscription.'**
  String get subscriptionFooterManage;

  /// No description provided for @subscriptionCtaSubscribe.
  ///
  /// In en, this message translates to:
  /// **'Subscribe for {price}/mo'**
  String subscriptionCtaSubscribe(String price);

  /// No description provided for @subscriptionCtaManage.
  ///
  /// In en, this message translates to:
  /// **'Manage Subscription'**
  String get subscriptionCtaManage;

  /// Subscription CTA label when subscribed by partner.
  ///
  /// In en, this message translates to:
  /// **'Thanks to {name}'**
  String subscriptionCtaThanks(String name);

  /// No description provided for @subscriptionFreeBadge.
  ///
  /// In en, this message translates to:
  /// **'Free for 7 days'**
  String get subscriptionFreeBadge;

  /// No description provided for @subscriptionLinkPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get subscriptionLinkPrivacy;

  /// No description provided for @subscriptionLinkRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get subscriptionLinkRestore;

  /// No description provided for @subscriptionLinkTerms.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get subscriptionLinkTerms;

  /// No description provided for @subscriptionToastWelcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Scenes HD.'**
  String get subscriptionToastWelcome;

  /// No description provided for @subscriptionToastRestored.
  ///
  /// In en, this message translates to:
  /// **'Subscription restored.'**
  String get subscriptionToastRestored;

  /// No description provided for @subscriptionToastNothingToRestore.
  ///
  /// In en, this message translates to:
  /// **'No purchases to restore.'**
  String get subscriptionToastNothingToRestore;

  /// No description provided for @notificationsBannerTitle.
  ///
  /// In en, this message translates to:
  /// **'Turn on notifications'**
  String get notificationsBannerTitle;

  /// Banner body when partner display name is available.
  ///
  /// In en, this message translates to:
  /// **'Enable in Settings to receive {name}\'s activity and updates.'**
  String notificationsBannerBodyWithName(String name);

  /// No description provided for @notificationsBannerBodyNoName.
  ///
  /// In en, this message translates to:
  /// **'Enable in Settings to receive your partner\'s activity and updates.'**
  String get notificationsBannerBodyNoName;

  /// No description provided for @notificationsLoadError.
  ///
  /// In en, this message translates to:
  /// **'Could not load preferences.'**
  String get notificationsLoadError;

  /// No description provided for @notificationsPartnerActivityLabel.
  ///
  /// In en, this message translates to:
  /// **'Partner activity'**
  String get notificationsPartnerActivityLabel;

  /// No description provided for @notificationsPartnerActivityDesc.
  ///
  /// In en, this message translates to:
  /// **'When your partner adds scenes, moments, or likes yours.'**
  String get notificationsPartnerActivityDesc;

  /// No description provided for @notificationsAppNewsLabel.
  ///
  /// In en, this message translates to:
  /// **'App news'**
  String get notificationsAppNewsLabel;

  /// No description provided for @notificationsAppNewsDesc.
  ///
  /// In en, this message translates to:
  /// **'Updates about new features and announcements.'**
  String get notificationsAppNewsDesc;

  /// No description provided for @signOutConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign Out?'**
  String get signOutConfirmTitle;

  /// No description provided for @signOutConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'You will need to sign in again to use Scenes.'**
  String get signOutConfirmMessage;

  /// No description provided for @signOutConfirmAction.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get signOutConfirmAction;

  /// No description provided for @disconnectConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Disconnect?'**
  String get disconnectConfirmTitle;

  /// No description provided for @disconnectConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'You and your person will be unpaired.'**
  String get disconnectConfirmMessage;

  /// No description provided for @disconnectConfirmNotice.
  ///
  /// In en, this message translates to:
  /// **'All data tied to this relationship (scenes, photos, films, music, places, reactions, etc.) will be permanently deleted 6 months later.'**
  String get disconnectConfirmNotice;

  /// No description provided for @disconnectSignTitle.
  ///
  /// In en, this message translates to:
  /// **'Final check'**
  String get disconnectSignTitle;

  /// No description provided for @disconnectSignHeading.
  ///
  /// In en, this message translates to:
  /// **'Type UNPAIR to confirm the disconnect.'**
  String get disconnectSignHeading;

  /// No description provided for @disconnectSignPhrase.
  ///
  /// In en, this message translates to:
  /// **'UNPAIR'**
  String get disconnectSignPhrase;

  /// No description provided for @disconnectSignInputHint.
  ///
  /// In en, this message translates to:
  /// **'Type UNPAIR'**
  String get disconnectSignInputHint;

  /// No description provided for @disconnectConfirmAction.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get disconnectConfirmAction;

  /// No description provided for @disconnectFailedToast.
  ///
  /// In en, this message translates to:
  /// **'Failed to disconnect.'**
  String get disconnectFailedToast;

  /// No description provided for @deleteAccountConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete account?'**
  String get deleteAccountConfirmTitle;

  /// No description provided for @deleteAccountConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'This cannot be undone.'**
  String get deleteAccountConfirmMessage;

  /// No description provided for @deleteAccountConfirmNotice.
  ///
  /// In en, this message translates to:
  /// **'Your account and all relationship data (scenes, photos, films, music, places, reactions, etc.) will be permanently deleted right away. Your partner will lose access too.'**
  String get deleteAccountConfirmNotice;

  /// No description provided for @deleteAccountSignTitle.
  ///
  /// In en, this message translates to:
  /// **'Final check'**
  String get deleteAccountSignTitle;

  /// No description provided for @deleteAccountSignHeading.
  ///
  /// In en, this message translates to:
  /// **'Type DELETE to permanently remove your account.'**
  String get deleteAccountSignHeading;

  /// No description provided for @deleteAccountSignPhrase.
  ///
  /// In en, this message translates to:
  /// **'DELETE'**
  String get deleteAccountSignPhrase;

  /// No description provided for @deleteAccountSignInputHint.
  ///
  /// In en, this message translates to:
  /// **'Type DELETE'**
  String get deleteAccountSignInputHint;

  /// No description provided for @deleteAccountSignAction.
  ///
  /// In en, this message translates to:
  /// **'Delete forever'**
  String get deleteAccountSignAction;

  /// No description provided for @deleteAccountSignDeleting.
  ///
  /// In en, this message translates to:
  /// **'Deleting…'**
  String get deleteAccountSignDeleting;

  /// No description provided for @deleteAccountConfirmAction.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteAccountConfirmAction;

  /// No description provided for @deleteAccountFailedToast.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete account.'**
  String get deleteAccountFailedToast;

  /// No description provided for @deleteAccountActiveSubTitle.
  ///
  /// In en, this message translates to:
  /// **'Active subscription'**
  String get deleteAccountActiveSubTitle;

  /// No description provided for @deleteAccountActiveSubMessage.
  ///
  /// In en, this message translates to:
  /// **'Cancel your subscription in System Settings to stop being charged. Deleting your account here does not cancel it.'**
  String get deleteAccountActiveSubMessage;

  /// No description provided for @deleteAccountActiveSubConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete anyway'**
  String get deleteAccountActiveSubConfirm;

  /// No description provided for @deleteAccountActiveSubCancel.
  ///
  /// In en, this message translates to:
  /// **'Manage subscription'**
  String get deleteAccountActiveSubCancel;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @settingsAppVersion.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get settingsAppVersion;

  /// 프로필 Credits 섹션의 더보기 버튼 라벨.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get creditMoreButton;

  /// 설정 화면의 앱 잠금 항목 라벨.
  ///
  /// In en, this message translates to:
  /// **'App Lock'**
  String get settingsAppLock;

  /// No description provided for @lockTitleSetup.
  ///
  /// In en, this message translates to:
  /// **'Set Up Lock'**
  String get lockTitleSetup;

  /// No description provided for @lockTitleChange.
  ///
  /// In en, this message translates to:
  /// **'Change PIN'**
  String get lockTitleChange;

  /// No description provided for @lockTitleVerify.
  ///
  /// In en, this message translates to:
  /// **'Confirm PIN'**
  String get lockTitleVerify;

  /// No description provided for @lockEnterCurrent.
  ///
  /// In en, this message translates to:
  /// **'Enter your current PIN'**
  String get lockEnterCurrent;

  /// No description provided for @lockEnterCurrentDesc.
  ///
  /// In en, this message translates to:
  /// **'We\'ll verify it before continuing.'**
  String get lockEnterCurrentDesc;

  /// No description provided for @lockEnterNew.
  ///
  /// In en, this message translates to:
  /// **'Enter a new 4-digit PIN'**
  String get lockEnterNew;

  /// No description provided for @lockEnterNewDesc.
  ///
  /// In en, this message translates to:
  /// **'You\'ll use this to unlock the app.'**
  String get lockEnterNewDesc;

  /// No description provided for @lockConfirmNew.
  ///
  /// In en, this message translates to:
  /// **'Confirm your new PIN'**
  String get lockConfirmNew;

  /// No description provided for @lockConfirmNewDesc.
  ///
  /// In en, this message translates to:
  /// **'Re-enter the same PIN.'**
  String get lockConfirmNewDesc;

  /// No description provided for @lockSettingsHeader.
  ///
  /// In en, this message translates to:
  /// **'App Lock'**
  String get lockSettingsHeader;

  /// No description provided for @lockSettingsEnabledDesc.
  ///
  /// In en, this message translates to:
  /// **'App Lock is on.'**
  String get lockSettingsEnabledDesc;

  /// No description provided for @lockSettingsDisabledDesc.
  ///
  /// In en, this message translates to:
  /// **'Require a PIN to open the app.'**
  String get lockSettingsDisabledDesc;

  /// No description provided for @lockSetUpButton.
  ///
  /// In en, this message translates to:
  /// **'Set Up PIN'**
  String get lockSetUpButton;

  /// No description provided for @lockChangePinButton.
  ///
  /// In en, this message translates to:
  /// **'Change PIN'**
  String get lockChangePinButton;

  /// No description provided for @lockDisableButton.
  ///
  /// In en, this message translates to:
  /// **'Turn Off App Lock'**
  String get lockDisableButton;

  /// No description provided for @lockBiometricToggle.
  ///
  /// In en, this message translates to:
  /// **'Unlock with Face ID / Touch ID'**
  String get lockBiometricToggle;

  /// No description provided for @lockBiometricUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Biometric authentication is not available on this device.'**
  String get lockBiometricUnavailable;

  /// No description provided for @lockRecoveryNotice.
  ///
  /// In en, this message translates to:
  /// **'If you forget your PIN, sign in again to reset App Lock.'**
  String get lockRecoveryNotice;

  /// No description provided for @lockChallengeTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter PIN'**
  String get lockChallengeTitle;

  /// No description provided for @lockBiometricPrompt.
  ///
  /// In en, this message translates to:
  /// **'Unlock Scenes'**
  String get lockBiometricPrompt;

  /// No description provided for @lockForgotPin.
  ///
  /// In en, this message translates to:
  /// **'Forgot PIN?'**
  String get lockForgotPin;

  /// No description provided for @lockForgotConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign Out?'**
  String get lockForgotConfirmTitle;

  /// No description provided for @lockForgotConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'Signing out will turn off App Lock.\nAfter signing in again, you\'ll need to set it up from Settings.'**
  String get lockForgotConfirmBody;

  /// No description provided for @lockForgotConfirmAction.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get lockForgotConfirmAction;

  /// No description provided for @lockDisableConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Turn Off App Lock?'**
  String get lockDisableConfirmTitle;

  /// No description provided for @lockDisableConfirmBody.
  ///
  /// In en, this message translates to:
  /// **'PIN and biometric settings will be cleared.'**
  String get lockDisableConfirmBody;

  /// No description provided for @lockDisableConfirmAction.
  ///
  /// In en, this message translates to:
  /// **'Turn Off'**
  String get lockDisableConfirmAction;
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
