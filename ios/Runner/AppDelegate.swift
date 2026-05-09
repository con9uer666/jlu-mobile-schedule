import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {

  // Widget 点课程后,iOS 用 schedule://course?id=... 打开 app。
  // 把 courseId 缓存给 MethodChannel,等 Dart 端来取。
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
