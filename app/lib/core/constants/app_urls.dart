/// 앱 안에서 외부로 보내는 URL 한곳에 모아둠. 정책 페이지 호스팅을 옮기거나
/// 커스텀 도메인을 붙일 때 여기만 갱신하면 settings/subscription 양쪽에 일괄
/// 반영.
class AppUrls {
  const AppUrls._();

  /// 개인정보 처리 방침. GitHub Pages SPA의 `/scenes/privacy` 라우트.
  static const String privacyPolicy =
      'https://victorlee917.github.io/scenes/privacy';

  /// 서비스 이용 약관. GitHub Pages SPA의 `/scenes/terms` 라우트.
  static const String termsOfService =
      'https://victorlee917.github.io/scenes/terms';

  /// Scenes 인스타그램 계정.
  static const String instagram =
      'https://www.instagram.com/scenessinceyou';
}
