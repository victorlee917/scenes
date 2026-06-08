/// 앱 안에서 외부로 보내는 URL 한곳에 모아둠. 정책 페이지 호스팅을 옮기거나
/// 커스텀 도메인을 붙일 때 여기만 갱신하면 settings/subscription 양쪽에 일괄
/// 반영.
class AppUrls {
  const AppUrls._();

  /// 개인정보 처리 방침. scenes.id 웹의 `/privacy` 라우트.
  static const String privacyPolicy = 'https://scenes.id/privacy';

  /// 서비스 이용 약관. scenes.id 웹의 `/terms` 라우트.
  static const String termsOfService = 'https://scenes.id/terms';

  /// Scenes 인스타그램 계정.
  static const String instagram =
      'https://www.instagram.com/scenessinceyou';

  /// 앱 다운로드 — App Store 직링크. 초대 메시지에 포함.
  /// 국가 코드(`/us/`)와 앱 슬러그를 빼고 `/app/id<id>`만 두면 Apple이 방문자
  /// 지역 스토어로 자동 리다이렉트(US 고정 방지).
  static const String appDownload =
      'https://apps.apple.com/app/id6767381832';

  /// 커플 공유 페이지 base. 뒤에 커플 닉네임(slug)을 붙여 공유 URL을 만든다
  /// (`${shareBaseUrl}<slug>`). 도메인 바로 뒤에 slug가 온다(`scenes.id/<slug>`).
  /// 표시·복사·공유 모두 이 base를 사용 — 도메인 변경 시 여기만 갱신. trailing
  /// slash 포함.
  static const String shareBaseUrl = 'https://scenes.id/';

  /// 공유 URL의 표시용(스킴 제거) 형태. 카드/시트에서 `scenes.id/<slug>`로
  /// 짧게 보여줄 때 사용.
  static String shareDisplayUrl(String slug) =>
      '${shareBaseUrl.replaceFirst(RegExp(r'^https?://'), '')}$slug';

  /// 복사·공유에 쓰는 전체 URL.
  static String shareFullUrl(String slug) => '$shareBaseUrl$slug';

  /// 특정 Scene의 공유 URL — 웹 라우트 `scenes.id/<slug>/<sceneNumber>`와 일치.
  static String shareSceneFullUrl(String slug, int sceneNumber) =>
      '$shareBaseUrl$slug/$sceneNumber';

  /// 특정 Scene 공유 URL의 표시용(스킴 제거) 형태.
  static String shareSceneDisplayUrl(String slug, int sceneNumber) =>
      '${shareDisplayUrl(slug)}/$sceneNumber';
}
