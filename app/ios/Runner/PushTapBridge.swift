import Flutter
import Foundation

/// 알림 탭 페이로드를 Dart로 즉시 전달하는 채널.
///
/// AppDelegate가 `didReceive`에서 호출 — payload(JSON 문자열)를 invokeMethod로
/// flush. Dart는 `'scenes.app/push_tap'` 채널의 `'onTap'` 콜백에서 받는다.
///
/// 콜드 스타트 시점엔 Flutter 엔진이 아직 연결 전이라 channel 메시지가 유실될 수
/// 있어 NSUserDefaults에도 같은 페이로드를 적어둔다(AppDelegate 측). 그쪽은
/// initState에서 한 번 드레인.
final class PushTapBridge {
  private let channel: FlutterMethodChannel

  init(messenger: FlutterBinaryMessenger) {
    self.channel = FlutterMethodChannel(
      name: "scenes.app/push_tap",
      binaryMessenger: messenger
    )
  }

  func sendTap(payloadJson: String) {
    channel.invokeMethod("onTap", arguments: payloadJson)
  }
}
