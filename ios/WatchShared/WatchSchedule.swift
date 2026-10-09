import Foundation

struct WatchCourse: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let location: String
    let startTime: String
    let endTime: String
}

struct WatchDay: Codable, Identifiable, Equatable {
    let date: String
    let week: Int
    let courses: [WatchCourse]
    var id: String { date }
}

struct WatchSchedule: Codable, Equatable {
    let schemaVersion: Int
    let updatedAt: Double
    let utcOffsetSeconds: Int
    let semesterId: String?
    let semesterName: String
    let startDate: String?
    let endDate: String?
    let days: [WatchDay]

    var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: utcOffsetSeconds) ?? .current
        value.firstWeekday = 2
        return value
    }

    func dateKey(_ date: Date) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }

    func date(from key: String) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }

    func time(_ text: String, on date: Date) -> Date? {
        let parts = text.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2, (0...23).contains(parts[0]), (0...59).contains(parts[1]) else { return nil }
        return calendar.date(bySettingHour: parts[0], minute: parts[1], second: 0, of: date)
    }

    func day(on date: Date) -> WatchDay? {
        days.first { $0.date == dateKey(date) }
    }

    func courses(on date: Date) -> [WatchCourse] {
        (day(on: date)?.courses ?? []).sorted {
            ($0.startTime, $0.id) < ($1.startTime, $1.id)
        }
    }

    // A course starting at this instant is already current, not "next".
    func next(at now: Date) -> WatchNextCourse {
        guard semesterId != nil else { return .noSemester }
        if let course = courses(on: now).first(where: {
            guard let start = time($0.startTime, on: now) else { return false }
            return start > now
        }) {
            return .course(course, tomorrow: false)
        }
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now)!
        if let course = courses(on: tomorrow).first(where: { time($0.startTime, on: tomorrow) != nil }) {
            return .course(course, tomorrow: true)
        }
        return .noClassTomorrow
    }

    // Precompute midnight and class-start transitions; no per-minute polling.
    func transitionDates(after now: Date, numberOfDays: Int = 7) -> [Date] {
        var dates: Set<Date> = [now]
        let today = calendar.startOfDay(for: now)
        for offset in 0...numberOfDays {
            let date = calendar.date(byAdding: .day, value: offset, to: today)!
            if date > now { dates.insert(date) }
            for course in courses(on: date) {
                if let start = time(course.startTime, on: date), start > now {
                    dates.insert(start)
                }
            }
        }
        return Array(dates.sorted().prefix(100))
    }

    static func decode(_ data: Data) throws -> WatchSchedule {
        let schedule = try JSONDecoder().decode(Self.self, from: data)
        guard schedule.schemaVersion == 1 else { throw WatchScheduleError.unsupportedVersion }
        return schedule
    }
}

enum WatchNextCourse: Equatable {
    case course(WatchCourse, tomorrow: Bool)
    case noClassTomorrow
    case noSemester
}

enum WatchScheduleError: Error {
    case unsupportedVersion
    case sharedContainerUnavailable
}

// Compression keeps a whole semester below WatchConnectivity's context limit.
// Very large schedules use a file transfer instead (the same decoded schema).
enum WatchScheduleTransport {
    static let payloadKey = "scheduleLZFSE"
    static func pack(_ data: Data) throws -> Data {
        try (data as NSData).compressed(using: .lzfse) as Data
    }
    static func unpack(_ data: Data) throws -> Data {
        try (data as NSData).decompressed(using: .lzfse) as Data
    }
}
