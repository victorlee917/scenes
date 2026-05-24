import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  // VideoComposer / PlaceSearch는 implicit engine 수명 동안 살아있어야 —
  // channel handler가 self를 weakly hold하므로 강한 참조를 AppDelegate가
  // 들고 있음.
  private var videoComposer: VideoComposer?
  private var placeSearch: PlaceSearch?
  private var pushTapBridge: PushTapBridge?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // 이미 권한이 있는 사용자는 APNs 등록을 명시적으로 트리거해야 토큰이
    // 발급됨. firebase_messaging은 requestPermission() 호출에 한해서만 자동
    // 등록을 걸어 — 두 번째 launch부터는 우리가 직접 불러줘야 함.
    UNUserNotificationCenter.current().getNotificationSettings { settings in
      let authStatus = settings.authorizationStatus
      if authStatus == .authorized || authStatus == .provisional {
        DispatchQueue.main.async {
          application.registerForRemoteNotifications()
        }
      }
    }

    // FlutterImplicitEngine 셋업 특성상 firebase_messaging 플러그인이 늦게
    // 등록되어 launch notification + 알림 탭 이벤트를 잡지 못함. 그래서 우리가
    // UNUserNotificationCenter 델리게이트로 직접 받아 NSUserDefaults에
    // 적어두면, Dart가 SharedPreferences로 읽어 처리.
    UNUserNotificationCenter.current().delegate = self

    // 콜드 스타트 from notification — launchOptions에 페이로드 들어옴.
    if let remote = launchOptions?[.remoteNotification] as? [AnyHashable: Any] {
      persistPendingPushTap(remote)
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // 알림을 사용자가 탭하면 호출됨 (background → foreground, 콜드 스타트 둘 다).
  // 페이로드를 NSUserDefaults에 적어두고 super로 forwarding — 다른 plugin이
  // 같은 이벤트를 가로채는 것 방지.
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let userInfo = response.notification.request.content.userInfo
    persistPendingPushTap(userInfo)
    super.userNotificationCenter(center, didReceive: response, withCompletionHandler: completionHandler)
  }

  // 앱이 foreground일 때 알림 도착 시 호출. 기본 iOS 동작은 banner 표시 안
  // 함 — 우리가 명시적으로 banner+sound 옵션 줘야 보임. 사용자가 그 banner를
  // 탭하면 위 didReceive로 흘러가 deeplink 처리됨.
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    if #available(iOS 14.0, *) {
      completionHandler([.banner, .list, .sound])
    } else {
      completionHandler([.alert, .sound])
    }
  }

  // FCM payload는 평탄한 string 키/값이라 JSON 직렬화 가능. 두 갈래로 흘림:
  //  1. NSUserDefaults('flutter.pendingPushTap') — 콜드 스타트 fallback (Dart
  //     initState에서 SharedPreferences로 드레인).
  //  2. PushTapBridge method channel — 앱이 foreground/background로 떠 있을
  //     때 즉시 Dart에 전달. lifecycle 변동 없어도(=foreground 탭) 실시간 발화.
  private func persistPendingPushTap(_ userInfo: [AnyHashable: Any]) {
    var clean: [String: Any] = [:]
    for (k, v) in userInfo {
      if let key = k as? String { clean[key] = v }
    }
    guard JSONSerialization.isValidJSONObject(clean),
          let data = try? JSONSerialization.data(withJSONObject: clean, options: []),
          let json = String(data: data, encoding: .utf8) else { return }
    UserDefaults.standard.set(json, forKey: "flutter.pendingPushTap")
    // Flutter 엔진이 활성 상태면 즉시 push, 아니면 묵음. NSUserDefaults
    // fallback이 콜드 스타트 케이스를 커버.
    pushTapBridge?.sendTap(payloadJson: json)
  }

  // 네이티브 APNs 등록 실패 콜백 — 에러 메시지를 UserDefaults에 저장해
  // Dart 진단 로거(push_debug_log)가 읽어서 서버에 남기도록.
  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    let nsError = error as NSError
    let msg = "code=\(nsError.code) domain=\(nsError.domain) desc=\(nsError.localizedDescription)"
    UserDefaults.standard.set(msg, forKey: "flutter.lastAPNSRegisterError")
    super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // 네이티브 MethodChannel 등록. registrar의 messenger를 통해 binary
    // 메신저에 직접 attach. 내부 API라 보통 항상 non-nil이지만 safety 차원에서
    // 옵셔널 바인딩으로 가드.
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "VideoComposer") {
      self.videoComposer = VideoComposer(messenger: registrar.messenger())
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "PlaceSearch") {
      self.placeSearch = PlaceSearch(messenger: registrar.messenger())
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "PushTapBridge") {
      self.pushTapBridge = PushTapBridge(messenger: registrar.messenger())
    }
  }
}
