import SwiftUI

@main
struct ScheduleWatchApp: App {
    @WKApplicationDelegateAdaptor(ScheduleWatchDelegate.self) private var delegate
    var body: some Scene {
        WindowGroup { WatchScheduleView() }
    }
}
