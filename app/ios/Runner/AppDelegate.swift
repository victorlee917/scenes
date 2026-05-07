import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  // VideoComposer는 implicit engine 수명 동안 살아있어야 — channel handler가
  // self를 weakly hold하므로 강한 참조를 AppDelegate가 들고 있음.
  private var videoComposer: VideoComposer?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // VideoComposer MethodChannel 등록. registrar의 messenger를 통해 binary
    // 메신저에 직접 attach. 내부 API라 보통 항상 non-nil이지만 safety 차원에서
    // 옵셔널 바인딩으로 가드.
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "VideoComposer") {
      self.videoComposer = VideoComposer(messenger: registrar.messenger())
    }
  }
}
