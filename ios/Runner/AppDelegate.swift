import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {

  private var pendingCourseId: String?
  private var methodChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if let url = launchOptions?[.url] as? URL {
      pendingCourseId = parseCourseId(from: url)
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    if let id = parseCourseId(from: url) {
      pendingCourseId = id
      methodChannel?.invokeMethod("onCourseTap", arguments: id)
    }
    return super.application(app, open: url, options: options)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // iOS 26 Liquid Glass：让 Flutter window 背景透明，底层插入 UIVisualEffectView。
    // iOS 26 会自动将 UIBlurEffect(style: .systemMaterial) 升级为 Liquid Glass 渲染。
    if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
       let window = scene.windows.first(where: { $0.isKeyWindow }),
       let rootVC = window.rootViewController {
      rootVC.view.backgroundColor = .clear
      let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
      blur.frame = rootVC.view.bounds
      blur.autoresizingMask = [.flexibleWidth, .flexibleHeight]
      rootVC.view.insertSubview(blur, at: 0)
    }

    let channel = FlutterMethodChannel(
      name: "com.jlu.schedule/widget",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "consumeInitialCourseId":
        let id = self?.pendingCourseId
        self?.pendingCourseId = nil
        result(id)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    methodChannel = channel
  }

  private func parseCourseId(from url: URL) -> String? {
    guard url.scheme == "schedule" else { return nil }
    guard url.host == "course" else { return nil }
    let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
    return comps?.queryItems?.first(where: { $0.name == "id" })?.value
  }
}
