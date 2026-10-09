import Foundation

// App groups share data between the watch app and its complication on the
// watch itself. WatchConnectivity handles the separate phone-to-watch link.
enum WatchScheduleStore {
    static let widgetKind = "WatchNextCourse"
    static var fileURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.jlu.schedule")?
            .appendingPathComponent("watch-schedule.json")
    }

    static func load() -> WatchSchedule? {
        guard let url = fileURL, let data = try? Data(contentsOf: url) else { return nil }
        return try? WatchSchedule.decode(data)
    }

    @discardableResult
    static func save(_ data: Data) throws -> WatchSchedule {
        let schedule = try WatchSchedule.decode(data)
        if let current = load(), current.updatedAt > schedule.updatedAt { return current }
        guard let url = fileURL else { throw WatchScheduleError.sharedContainerUnavailable }
        try data.write(to: url, options: .atomic)
        return schedule
    }
}
