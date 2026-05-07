import 'package:flutter/material.dart';

/// 네이티브 스플래시(`flutter_native_splash`)와 시각적으로 동일한 in-app
/// 위젯. native splash가 제거된 직후~첫 화면이 데이터 로드 끝낼 때까지의
/// 짧은 공백을 같은 모양으로 메워 사용자에게 splash → home이 한 번에 이어
/// 지는 듯한 인상을 줌.
///
/// 색·이미지는 항상 다크 변형 — pubspec.yaml의 flutter_native_splash 설정과
/// 1:1 매칭(`color: #151517`, `image: assets/logo/logo_dark.png`).
class SplashView extends StatelessWidget {
  const SplashView({super.key});

  static const _splashColor = Color(0xFF151517);
  static const _logoSize = 192.0;

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: _splashColor,
      child: Center(
        child: Image(
          image: AssetImage('assets/logo/logo_dark.png'),
          width: _logoSize,
          height: _logoSize,
        ),
      ),
    );
  }
}
