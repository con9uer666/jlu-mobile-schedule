import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  static var pendingCourseId: String?
  static weak var channel: FlutterMethodChannel?

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  override func application(_ application: NSApplication, open urls: [URL]) {
    for url in urls {
      guard let id = Self.parseCourseId(from: url) else { continue }
      Self.pendingCourseId = id
      Self.channel?.invokeMethod("onCourseTap", arguments: id)
    }
  }

  static func parseCourseId(from url: URL) -> String? {
    guard url.scheme == "schedule", url.host == "course" else { return nil }
    return URLComponents(url: url, resolvingAgainstBaseURL: false)?
      .queryItems?.first(where: { $0.name == "id" })?.value
  }
}
