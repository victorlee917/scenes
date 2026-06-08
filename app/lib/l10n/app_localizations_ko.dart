// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

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
  String get sceneListA11yLabel => 'Scene 목록';

  @override
  String get transportSort => 'Scene 정렬';

  @override
  String get transportAdd => 'Scene 추가';

  @override
  String get transportRecap => 'Rewind';

  @override
  String get addSceneCardLabel => '새 Scene 추가';

  @override
  String get homeEmptyTaglinePrefix => '우리가 함께 한 ';

  @override
  String get homeEmptyTaglineBrand => 'Scene';

  @override
  String get homeEmptyTaglineSuffix => '을\n간직해 보세요.';

  @override
  String get detailBack => '뒤로';

  @override
  String get detailMoreActions => 'Scene 작업';

  @override
  String get sceneListEditOrder => '순서 편집';

  @override
  String get sceneListNewestFirst => '최신 순';

  @override
  String get sceneListOldestFirst => '오래된 순';

  @override
  String get sceneListSave => '저장';

  @override
  String get sceneDetailEdit => 'Scene 편집';

  @override
  String get sceneDetailEditDate => '날짜 편집';

  @override
  String get sceneDetailEditDateSheetTitle => '날짜 편집';

  @override
  String get sceneDetailEditDateSheetInfo =>
      '이 Scene의 모든 Moment 날짜를 한 번에 설정합니다.';

  @override
  String get sceneDetailEditDateFailedToast => '날짜 변경에 실패했어요.';

  @override
  String get actionDelete => '삭제';

  @override
  String get actionRemove => '제거';

  @override
  String get reactionPickerUpdate => '수정';

  @override
  String get reactionPickerCommentHint => '코멘트를 남겨 보세요 (선택)';

  @override
  String get reactionPickerHdUpsellSubtitle => '리액션에 코멘트를 남겨 보세요.';

  @override
  String get sceneDetailShare => 'Scene 공유';

  @override
  String get sceneDetailAddMedia => 'Moment 추가';

  @override
  String get profileSettings => '설정';

  @override
  String get settingsTitle => '설정';

  @override
  String get settingsSectionPreferences => '환경 설정';

  @override
  String get settingsSectionAbout => '정보';

  @override
  String get settingsSectionAccount => '계정';

  @override
  String get settingsTheme => '테마';

  @override
  String get settingsPushNotifications => '알림';

  @override
  String get settingsLanguage => '언어';

  @override
  String get languageScreenTitle => '언어';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageKorean => '한국어';

  @override
  String get languageSystem => '디바이스 언어 사용';

  @override
  String get themeScreenTitle => '테마';

  @override
  String get themeDark => '다크';

  @override
  String get themeLight => '라이트';

  @override
  String get themeSystem => '디바이스 테마 사용';

  @override
  String get settingsPrivacyPolicy => '개인정보처리방침';

  @override
  String get settingsTermsOfService => '서비스이용약관';

  @override
  String get settingsInstagram => 'Scenes 인스타그램';

  @override
  String get settingsLogout => '로그아웃';

  @override
  String get settingsDisconnect => '연결 해지';

  @override
  String get settingsDeleteAccount => '계정 삭제';

  @override
  String get settingsDangerZone => '위험';

  @override
  String get dangerZoneTitle => '위험';

  @override
  String uploadChipPhotosProgress(int current, int total) {
    return '$current / $total 업로드 중';
  }

  @override
  String get uploadChipFilmActive => '영화 추가 중…';

  @override
  String get uploadChipMusicActive => '음악 추가 중…';

  @override
  String get uploadChipPlaceActive => '장소 추가 중…';

  @override
  String uploadChipPhotosDone(int count) {
    return '사진 $count장 추가됨';
  }

  @override
  String get uploadChipFilmDone => '영화 추가됨';

  @override
  String get uploadChipMusicDone => '음악 추가됨';

  @override
  String get uploadChipPlaceDone => '장소 추가됨';

  @override
  String get uploadChipFailed => '업로드 실패';

  @override
  String get uploadChipCancelling => '취소 중…';

  @override
  String get profileDeletedUserName => '탈퇴한 사용자';

  @override
  String get actionSave => '저장';

  @override
  String get imageCropperTitle => '자르기';

  @override
  String get editProfileNameHint => '이름';

  @override
  String get editProfileSaveFailed => '저장에 실패했습니다.';

  @override
  String get createSceneTitleHint => 'Scene 이름';

  @override
  String get createSceneCreate => '만들기';

  @override
  String get createSceneSaveFailed => 'Scene 저장에 실패했어요.';

  @override
  String get datePickerConfirm => '확인';

  @override
  String get mediaLabelPhoto => '사진';

  @override
  String get mediaLabelFilm => '영화';

  @override
  String get mediaLabelMusic => '음악';

  @override
  String get mediaLabelPlace => '장소';

  @override
  String get recapEmptyPhotos => '아직 돌아볼 사진이 없어요.';

  @override
  String get recapEmptyFilms => '아직 돌아볼 영화가 없어요.';

  @override
  String get recapEmptyMusic => '아직 돌아볼 음악이 없어요.';

  @override
  String get recapEmptyPlaces => '아직 돌아볼 장소가 없어요.';

  @override
  String get recapFilteredEmptyPhotos => '선택한 Scene에 사진이 없어요.';

  @override
  String get recapFilteredEmptyFilms => '선택한 Scene에 영화가 없어요.';

  @override
  String get recapFilteredEmptyMusic => '선택한 Scene에 음악이 없어요.';

  @override
  String get recapFilteredEmptyPlaces => '선택한 Scene에 장소가 없어요.';

  @override
  String get reactionSaveFailed => '리액션 저장에 실패했어요.';

  @override
  String get reactionRemoveFailed => '리액션 삭제에 실패했어요.';

  @override
  String get recapNavPrevious => '이전';

  @override
  String get recapNavNext => '다음';

  @override
  String get recapNavPreviousPlace => '이전 장소';

  @override
  String get recapNavNextPlace => '다음 장소';

  @override
  String get recapTicketReleased => '개봉';

  @override
  String get recapTicketRuntime => '러닝타임';

  @override
  String get recapTicketWatched => '관람';

  @override
  String runtimeMinutesValue(int minutes) {
    return '$minutes분';
  }

  @override
  String runtimeMinutesValueSpaced(int minutes) {
    return '$minutes분';
  }

  @override
  String get contentDetailFilmMovie => '영화';

  @override
  String get contentDetailFilmTvSeries => 'TV 시리즈';

  @override
  String get contentDetailMusicTrack => '트랙';

  @override
  String get contentDetailMusicAlbum => '앨범';

  @override
  String get contentDetailUpdateDateFailed => '날짜 변경에 실패했어요.';

  @override
  String get contentDetailDeleteMessage => '이 Scene에서 삭제됩니다.';

  @override
  String get contentDetailDeleteFailed => '삭제에 실패했어요.';

  @override
  String get actionApply => '적용';

  @override
  String get uploadCancelDialogMessage => '이미 업로드된 사진은 유지돼요.';

  @override
  String get uploadCancelKeepUploading => '계속 업로드';

  @override
  String get filterScenesAll => '모든 Scene';

  @override
  String get playSceneAction => '재생';

  @override
  String get playSceneStop => '중지';

  @override
  String get playSceneNoMomentsToast => '재생할 Moment가 없어요.';

  @override
  String get playSceneLoadingPreparing => 'Scene을 준비하고 있어요…';

  @override
  String get playSceneFilterNormal => 'Normal';

  @override
  String get playSceneFilterVintage => 'Vintage';

  @override
  String get playSceneFilterCinema => 'Cinema';

  @override
  String get playSceneFilterMono => 'Mono';

  @override
  String get playSceneSelectMoments => 'Moment 선택';

  @override
  String playSceneMomentsCount(int count) {
    return '$count개';
  }

  @override
  String get playSceneShuffle => '셔플';

  @override
  String get playSceneHdUpsellSubtitle => '재생에 필름 룩을 입혀 보세요.';

  @override
  String get playSceneShareFailedToast => '공유에 실패했어요.';

  @override
  String get playScenePhotoPermissionToast => '사진 권한이 필요해요.';

  @override
  String get playSceneSavedToPhotosToast => '사진 앱에 저장됨';

  @override
  String get playSceneInstagramMissingToast => 'Instagram이 설치되어 있지 않아요.';

  @override
  String get playSceneShareStory => 'Story';

  @override
  String get playSceneShareMore => '더보기';

  @override
  String get photoPickerScreenTitle => '사진 추가';

  @override
  String get photoPickerEmpty => '사진이 없어요';

  @override
  String get photoPickerAllPhotos => '모든 사진';

  @override
  String photoPickerBatchCapToast(int limit) {
    return '한 번에 최대 $limit장 업로드할 수 있어요.';
  }

  @override
  String get photoPickerSceneCapToast => 'Scene 업로드 한도에 도달했어요.';

  @override
  String get pickerSearchFailed => '검색에 실패했어요. 다시 시도해 주세요.';

  @override
  String get pickerNoResults => '검색 결과가 없어요.';

  @override
  String get filmPickerScreenTitle => '영화 추가';

  @override
  String get filmPickerSearchHint => '영화 검색…';

  @override
  String get filmPickerEmpty => '추가할 영화를 검색해 보세요.';

  @override
  String get filmPickerTmdbAttribution => '영화 데이터 제공: TMDB';

  @override
  String get musicPickerScreenTitle => '음악 추가';

  @override
  String get musicPickerSearchHint => '음악 검색…';

  @override
  String get musicPickerEmpty => '추가할 음악을 검색해 보세요.';

  @override
  String get musicPickerSpotifyAttribution => '음악 데이터 제공: Spotify';

  @override
  String get placePickerScreenTitle => '장소 추가';

  @override
  String get placePickerSearchHint => '장소 검색…';

  @override
  String get placePickerEmpty => '추가할 장소를 검색해 보세요.';

  @override
  String get placePickerAppleAttribution => 'Apple 지도 검색';

  @override
  String get placePickerScopeDomestic => '국내';

  @override
  String get placePickerScopeOverseas => '해외';

  @override
  String get onboardingGetStarted => '시작하기';

  @override
  String get onboardingContinueWithApple => 'Apple로 계속하기';

  @override
  String get onboardingContinueWithGoogle => 'Google로 계속하기';

  @override
  String get onboardingContinueWithKakao => '카카오로 계속하기';

  @override
  String get onboardingAgreementContinue => '동의하고 계속';

  @override
  String get authErrorNetwork => '연결 상태를 확인하고 다시 시도해 주세요.';

  @override
  String get authErrorGeneric => '로그인에 실패했어요. 다시 시도해 주세요.';

  @override
  String get actionContinue => '계속';

  @override
  String get sceneDetailDeleteMessage => '이 Scene의 모든 Moment도 함께 삭제됩니다.';

  @override
  String get sceneDetailDeleteFailedToast => 'Scene 삭제에 실패했어요.';

  @override
  String get sceneDetailReorderSaveFailedToast => '순서 저장에 실패했어요.';

  @override
  String get profileSetupTagline => '사진과 이름을 등록하면\n파트너가 알아볼 수 있어요.';

  @override
  String profileSetupNameHint(int max) {
    return '이름 (최대 $max자)';
  }

  @override
  String get profileSetupSaveFailedToast => '프로필 저장에 실패했어요.';

  @override
  String get pairingTagline => '초대 코드를 공유하거나\n파트너의 코드를 입력해 연결하세요.';

  @override
  String get pairingYourInviteCode => '내 초대 코드';

  @override
  String get pairingEnterPersonCodeButton => '파트너의 코드 입력';

  @override
  String get pairingActionCopy => '복사';

  @override
  String get pairingActionShare => '공유';

  @override
  String get pairingEnterCodeHint => '파트너의 코드';

  @override
  String get pairingEnterCodeAction => '연결';

  @override
  String get pairingCodeCopiedToast => '코드 복사됨';

  @override
  String pairingShareMessage(String link, String code) {
    return '우리의 장면을 함께 모아요, Scenes에서 💞\n\n앱 다운로드 → $link\n초대 코드: $code';
  }

  @override
  String get pairingFailedToast => '연결에 실패했어요. 다시 시도해 주세요.';

  @override
  String get pairingErrorInvalidCode => '유효하지 않은 코드예요.';

  @override
  String get pairingErrorAlreadyUsed => '이미 사용된 코드예요.';

  @override
  String get pairingErrorExpired => '만료된 코드예요.';

  @override
  String get pairingErrorOwnCode => '본인 코드는 사용할 수 없어요.';

  @override
  String get pairingErrorInviterUnavailable => '더 이상 사용할 수 없는 코드예요.';

  @override
  String get pairingErrorAlreadyPaired => '이미 다른 사람과 연결되어 있어요.';

  @override
  String get pairingCodeLoadError => '코드를 불러올 수 없어요. 다시 시도하려면 탭하세요.';

  @override
  String get pairingCodeExpiredBadge => '만료됨';

  @override
  String pairingCodeExpiresHours(int hours, int minutes) {
    return '$hours시간 $minutes분 후 만료';
  }

  @override
  String pairingCodeExpiresMinutes(int minutes) {
    return '$minutes분 후 만료';
  }

  @override
  String pairingCodeExpiresSeconds(int seconds) {
    return '$seconds초 후 만료';
  }

  @override
  String get pairingSignOutConfirmMessage => 'Scenes를 다시 사용하려면 다시 로그인해야 해요.';

  @override
  String get subscriptionUnavailableError => '지금은 구독을 사용할 수 없어요.';

  @override
  String get subscriptionGenericError => '구매에 실패했어요. 다시 시도해주세요.';

  @override
  String get sceneDetailPlay => 'Scene 재생';

  @override
  String get sceneDetailEmptyMedia => 'Scene을 소중한 순간들로 채워 보세요';

  @override
  String profileNarrative(
    String partnerA,
    String partnerB,
    String date,
    int count,
  ) {
    return '$partnerA와 $partnerB는 $date에 만나 $count개의 Scene을 찍었다.';
  }

  @override
  String coupleScenesCount(int count) {
    return '$count Scenes';
  }

  @override
  String notiPromptTitleWithName(String name) {
    return '$name님의 소식을\n놓치지 마세요';
  }

  @override
  String get notiPromptTitleNoName => '소중한 소식을\n놓치지 마세요';

  @override
  String notiPromptBodyWithName(String name) {
    return '$name님이\n새로운 Scene을 추가하거나\n반응을 남길 때 알려드릴게요.';
  }

  @override
  String get notiPromptBodyNoName => '파트너가 새로운 Scene을 추가하거나\n반응을 남길 때 알려드릴게요.';

  @override
  String get notiPromptAllow => '알림 허용';

  @override
  String get notiPromptSkip => '나중에 하기';

  @override
  String addMediaCapacityLabel(int count, int limit) {
    return 'Moment $count/$limit';
  }

  @override
  String get addMediaDateToday => '오늘';

  @override
  String addMediaToastSceneFull(int limit) {
    return 'Scene이 가득 찼어요 ($limit).';
  }

  @override
  String addMediaToastFreeLimit(int limit) {
    return '무료 Scene은 Moment $limit개까지 가능해요.';
  }

  @override
  String get hdBannerBenefitMedia => '영화, 음악, 장소까지 담아 보세요.';

  @override
  String get hdBannerBenefitMoments => '한 Scene에 Moment를 100개까지.';

  @override
  String get subscriptionTagline => '함께 한 장면을 더 생생하게';

  @override
  String get subscriptionBannerTaglineActive => '우리가 함께 한 장면들이 더 생생해지고 있어요.';

  @override
  String get subscriptionBannerLearnMore => '자세히 보기';

  @override
  String get shareCardTagline => '우리 이야기를 친구들에게 보여주세요.';

  @override
  String get shareCardSetPrompt => '공유하려면 닉네임을 설정하세요';

  @override
  String get shareAddressLabel => '공유 주소';

  @override
  String get shareIdSetNeeded => 'id 설정 필요';

  @override
  String get shareIdChange => 'id 변경';

  @override
  String get shareLinkCopied => '링크를 복사했어요';

  @override
  String get shareNicknameSheetDesc => '공유 페이지 주소로 사용돼요.';

  @override
  String get shareNicknameAvailable => '사용 가능';

  @override
  String get shareNicknameTaken => '이미 사용 중';

  @override
  String get shareNicknameInvalid => '영문·숫자·하이픈 3~30자';

  @override
  String get shareNicknameChangeWarning => '변경하면 현재 링크가 끊겨요.';

  @override
  String get shareNicknameSaveFailed => '저장에 실패했어요. 다시 시도해 주세요.';

  @override
  String get shareSceneLinkLabel => 'Scene 링크';

  @override
  String shareSceneSharedCount(int shared, int total) {
    return '$total개 중 $shared개 공유 중';
  }

  @override
  String get shareSelectMoments => 'Moment 선택';

  @override
  String get subscriptionFeaturePairTitle => '우리는 하나';

  @override
  String get subscriptionFeaturePairDesc => '한 명만 구독해도 Scenes HD가 적용돼요.';

  @override
  String get subscriptionFeatureMomentTypesTitle => '더 많은 Moment 타입';

  @override
  String get subscriptionFeatureMomentTypesDesc => '영화, 음악, 장소를 Scene에 추가하세요.';

  @override
  String get subscriptionFeatureMomentsPerSceneTitle => 'Scene당 더 많은 Moment';

  @override
  String get subscriptionFeatureMomentsPerSceneDesc =>
      'Scene마다 30개 대신 100개까지 담아 보세요.';

  @override
  String get subscriptionFeatureReactionCommentsTitle => '리액션 코멘트';

  @override
  String get subscriptionFeatureReactionCommentsDesc => '리액션에 코멘트를 덧붙여 보세요.';

  @override
  String get subscriptionFeatureReorderTitle => 'Scene · Moment 순서 변경';

  @override
  String get subscriptionFeatureReorderDesc => '원하는 순서대로 Scene과 Moment를 정리하세요.';

  @override
  String get subscriptionFeatureFiltersTitle => '재생 필터';

  @override
  String get subscriptionFeatureFiltersDesc => '필름 룩 필터로 재생 화면을 연출하세요.';

  @override
  String get subscriptionFeatureTemplatesTitle => '더 많은 공유 템플릿';

  @override
  String get subscriptionFeatureTemplatesDesc => 'Scene을 다양한 영상 템플릿으로 공유하세요.';

  @override
  String get subscriptionFooterPair =>
      '둘 중 한 명만 구독해도 Scenes HD가 두 사람 모두에게 적용됩니다.';

  @override
  String subscriptionFooterPlan(String price) {
    return 'Scenes HD는 월 $price 자동 갱신 구독이며, 신규 가입자에게 7일 무료 체험을 제공합니다.';
  }

  @override
  String subscriptionFooterTrialConversion(String price) {
    return '7일 무료 체험이 끝나면 자동으로 월 $price 유료 구독으로 전환됩니다.\n결제를 원치 않으시면 체험 종료 최소 24시간 전에 취소해 주세요.';
  }

  @override
  String get subscriptionFooterTrialEligibility =>
      '무료 체험은 신규 가입자에게만 제공됩니다. 이미 같은 Apple ID로 구독하신 적이 있다면(가족 공유 포함) 무료 체험을 다시 받지 못할 수 있습니다.';

  @override
  String get subscriptionFooterCharge => '구매 확정 시 Apple ID 계정으로 결제가 청구됩니다.';

  @override
  String subscriptionFooterRenewal(String price) {
    return '현재 기간 종료 최소 24시간 전에 자동 갱신을 끄지 않으면 구독은 자동으로 갱신됩니다. 현재 기간 종료 24시간 이내에 월 $price에 갱신 비용이 청구됩니다.';
  }

  @override
  String get subscriptionFooterManage =>
      '구매 후 App Store 계정 설정에서 구독을 관리하거나 취소할 수 있습니다. 유료 구독을 시작하면 무료 체험의 사용하지 않은 기간은 무효가 됩니다.';

  @override
  String subscriptionCtaSubscribe(String price) {
    return '월 $price 구독';
  }

  @override
  String get subscriptionCtaManage => '구독 관리';

  @override
  String subscriptionCtaThanks(String name) {
    return '$name 구독 중';
  }

  @override
  String get subscriptionFreeBadge => '7일 무료';

  @override
  String get subscriptionLinkPrivacy => '개인정보처리방침';

  @override
  String get subscriptionLinkRestore => '복구';

  @override
  String get subscriptionLinkTerms => '서비스이용약관';

  @override
  String get subscriptionToastWelcome => 'Scenes HD에 오신 것을 환영합니다.';

  @override
  String get subscriptionToastRestored => '구독이 복구되었습니다.';

  @override
  String get subscriptionToastNothingToRestore => '복구할 구매 내역이 없습니다.';

  @override
  String get notificationsBannerTitle => '알림 켜기';

  @override
  String notificationsBannerBodyWithName(String name) {
    return '$name님의 활동 소식을 받으려면 설정에서 알림을 켜 주세요.';
  }

  @override
  String get notificationsBannerBodyNoName =>
      '파트너의 활동 소식을 받으려면 설정에서 알림을 켜 주세요.';

  @override
  String get notificationsLoadError => '환경설정을 불러올 수 없습니다.';

  @override
  String get notificationsPartnerActivityLabel => '파트너 활동';

  @override
  String get notificationsPartnerActivityDesc =>
      '파트너가 Scene이나 Moment를 추가하거나 반응을 남길 때';

  @override
  String get notificationsAppNewsLabel => '앱 소식';

  @override
  String get notificationsAppNewsDesc => '새 기능과 공지사항 업데이트';

  @override
  String get signOutConfirmTitle => 'Sign Out?';

  @override
  String get signOutConfirmMessage => 'Scenes를 사용하려면 다시 로그인이 필요합니다.';

  @override
  String get signOutConfirmAction => '로그아웃';

  @override
  String get disconnectConfirmTitle => 'Disconnect?';

  @override
  String get disconnectConfirmMessage => '두 사람의 연결이 해지됩니다.';

  @override
  String get disconnectConfirmNotice =>
      '관계에 속한 모든 데이터(scene·사진·영화·음악·장소·리액션 등)는 6개월 뒤 영구 삭제돼요.';

  @override
  String get disconnectSignTitle => '마지막 확인';

  @override
  String get disconnectSignHeading => 'UNPAIR를 입력해 연결 해지를 확인해 주세요.';

  @override
  String get disconnectSignPhrase => 'UNPAIR';

  @override
  String get disconnectSignInputHint => 'UNPAIR 입력';

  @override
  String get disconnectConfirmAction => '연결 해지';

  @override
  String get disconnectFailedToast => '연결 해지에 실패했습니다.';

  @override
  String get deleteAccountConfirmTitle => 'Delete account?';

  @override
  String get deleteAccountConfirmMessage => '계정 삭제는 되돌릴 수 없습니다.';

  @override
  String get deleteAccountConfirmNotice =>
      '계정과 관계에 속한 모든 데이터(scene·사진·영화·음악·장소·리액션 등)가 즉시 영구 삭제돼요. 파트너도 접근할 수 없게 돼요.';

  @override
  String get deleteAccountSignTitle => '마지막 확인';

  @override
  String get deleteAccountSignHeading => 'DELETE를 입력해 영구 탈퇴를 확인해 주세요.';

  @override
  String get deleteAccountSignPhrase => 'DELETE';

  @override
  String get deleteAccountSignInputHint => 'DELETE 입력';

  @override
  String get deleteAccountSignAction => '영구 삭제';

  @override
  String get deleteAccountSignDeleting => '삭제 중…';

  @override
  String get deleteAccountConfirmAction => '계정 삭제';

  @override
  String get deleteAccountFailedToast => '계정 삭제에 실패했습니다.';

  @override
  String get deleteAccountActiveSubTitle => 'Active subscription';

  @override
  String get deleteAccountActiveSubMessage =>
      '결제가 계속되지 않도록 시스템 설정에서 구독을 해지하세요. 계정만 삭제해도 구독은 자동으로 해지되지 않습니다.';

  @override
  String get deleteAccountActiveSubConfirm => '삭제';

  @override
  String get deleteAccountActiveSubCancel => '구독 관리';

  @override
  String get commonCancel => '취소';

  @override
  String get settingsAppVersion => '앱 버전';

  @override
  String get creditMoreButton => '더보기';

  @override
  String get settingsAppLock => '앱 잠금';

  @override
  String get lockTitleSetup => '앱 잠금 설정';

  @override
  String get lockTitleChange => 'PIN 변경';

  @override
  String get lockTitleVerify => 'PIN 확인';

  @override
  String get lockEnterCurrent => '현재 PIN 입력';

  @override
  String get lockEnterCurrentDesc => '변경 전에 본인 확인을 진행해요.';

  @override
  String get lockEnterNew => '새 4자리 PIN 입력';

  @override
  String get lockEnterNewDesc => '앱을 잠금 해제할 때 사용해요.';

  @override
  String get lockConfirmNew => '새 PIN 확인';

  @override
  String get lockConfirmNewDesc => '같은 PIN을 다시 입력해주세요.';

  @override
  String get lockSettingsHeader => '앱 잠금';

  @override
  String get lockSettingsEnabledDesc => '앱 잠금이 켜져 있어요.';

  @override
  String get lockSettingsDisabledDesc => '앱을 열 때 PIN을 요구해요.';

  @override
  String get lockSetUpButton => 'PIN 설정';

  @override
  String get lockChangePinButton => 'PIN 변경';

  @override
  String get lockDisableButton => '앱 잠금 끄기';

  @override
  String get lockBiometricToggle => 'Face ID / Touch ID로 잠금 해제';

  @override
  String get lockBiometricUnavailable => '이 기기에서 생체 인증을 사용할 수 없어요.';

  @override
  String get lockRecoveryNotice => 'PIN을 잊은 경우, 다시 로그인하면 앱 잠금이 초기화돼요.';

  @override
  String get lockChallengeTitle => 'PIN 입력';

  @override
  String get lockBiometricPrompt => 'Scenes 잠금 해제';

  @override
  String get lockForgotPin => 'PIN을 잊으셨나요?';

  @override
  String get lockForgotConfirmTitle => 'Sign Out?';

  @override
  String get lockForgotConfirmBody =>
      '로그아웃하면 앱 잠금이 꺼져요.\n다시 로그인 후 설정에서 다시 설정해야 해요.';

  @override
  String get lockForgotConfirmAction => '로그아웃';

  @override
  String get lockDisableConfirmTitle => '앱 잠금을 끌까요?';

  @override
  String get lockDisableConfirmBody => 'PIN과 생체 인증 설정이 모두 지워져요.';

  @override
  String get lockDisableConfirmAction => '끄기';
}
