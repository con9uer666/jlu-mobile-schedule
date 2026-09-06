import Cocoa
import FlutterMacOS
import WidgetKit

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let initialFrame = NSRect(x: 0, y: 0, width: 420, height: 820)
    self.setFrame(initialFrame, display: true)
    self.contentViewController = flutterViewController
    self.minSize = NSSize(width: 380, height: 640)

    RegisterGeneratedPlugins(registry: flutterViewController)

    let channel = FlutterMethodChannel(
      name: "com.jlu.schedule/widget",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "consumeInitialCourseId":
        let id = AppDelegate.pendingCourseId
        AppDelegate.pendingCourseId = nil
        result(id)
      case "pushTodayPayload":
        guard let jsonString = call.arguments as? String,
              let defaults = UserDefaults(suiteName: "group.com.jlu.schedule") else {
          result(FlutterError(code: "BAD_ARGS", message: "expected String payload + valid app group", details: nil))
          return
        }
        defaults.set(jsonString, forKey: "today_payload")
        if #available(macOS 11.0, *) {
          WidgetCenter.shared.reloadAllTimelines()
        }
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    AppDelegate.channel = channel

    super.awakeFromNib()
  }
}
