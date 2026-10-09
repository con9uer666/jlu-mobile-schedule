import XCTest
@testable import WatchScheduleCore

final class WatchScheduleTests: XCTestCase {
    private let morning = WatchCourse(id: "m", name: "高等数学", location: "一教302", startTime: "08:00", endTime: "09:40")
    private let afternoon = WatchCourse(id: "a", name: "电子技术", location: "二教101", startTime: "13:30", endTime: "15:10")
    private func schedule(tomorrow: [WatchCourse] = []) -> WatchSchedule {
        WatchSchedule(schemaVersion: 1, updatedAt: 1, utcOffsetSeconds: 28800,
                      semesterId: "current", semesterName: "秋季", startDate: "2026-09-07", endDate: "2027-01-24",
                      days: [WatchDay(date: "2026-09-13", week: 1, courses: [afternoon, morning]),
                             WatchDay(date: "2026-09-14", week: 2, courses: tomorrow)])
    }
    private func instant(_ clock: String) -> Date { instant("2026-09-13", clock) }
    private func instant(_ day: String, _ clock: String) -> Date {
        let model = schedule()
        return model.time(clock, on: model.date(from: day)!)!
    }
    func testBeforeClassShowsFirstAndDuringClassSkipsCurrent() {
        let model = schedule()
        XCTAssertEqual(model.next(at: instant("07:59")), .course(morning, tomorrow: false))
        XCTAssertEqual(model.next(at: instant("08:00")), .course(afternoon, tomorrow: false))
        XCTAssertEqual(model.next(at: instant("09:00")), .course(afternoon, tomorrow: false))
    }
    func testLastClassAlreadyStartedShowsTomorrowFirstClass() {
        let model = schedule(tomorrow: [morning])
        XCTAssertEqual(model.next(at: instant("13:30")), .course(morning, tomorrow: true))
        XCTAssertEqual(model.next(at: instant("23:59")), .course(morning, tomorrow: true))
        XCTAssertEqual(model.next(at: instant("2026-09-14", "00:00")), .course(morning, tomorrow: false))
    }
    func testDoesNotSkipEmptyTomorrowToFindLaterCourse() {
        XCTAssertEqual(schedule().next(at: instant("13:30")), .noClassTomorrow)
        XCTAssertEqual(schedule().next(at: instant("2027-01-25", "07:00")), .noClassTomorrow)
    }
    func testTimelineHasStartAndMidnightTransitionsButNotEndTransitions() {
        let model = schedule(tomorrow: [morning])
        let dates = model.transitionDates(after: instant("07:59"))
        XCTAssertTrue(dates.contains(instant("08:00")))
        XCTAssertTrue(dates.contains(instant("13:30")))
        XCTAssertTrue(dates.contains(instant("2026-09-14", "00:00")))
        XCTAssertFalse(dates.contains(instant("09:40")))
        XCTAssertEqual(dates, Array(Set(dates)).sorted())
    }
    func testCompressionRoundtripAndUnsupportedSchema() throws {
        let original = try JSONEncoder().encode(schedule(tomorrow: [morning]))
        let packed = try WatchScheduleTransport.pack(original)
        let unpacked = try WatchScheduleTransport.unpack(packed)
        XCTAssertEqual(try WatchSchedule.decode(unpacked), schedule(tomorrow: [morning]))
        var json = try JSONSerialization.jsonObject(with: original) as! [String: Any]
        json["schemaVersion"] = 2
        XCTAssertThrowsError(try WatchSchedule.decode(JSONSerialization.data(withJSONObject: json)))
    }
    func testNoSemesterIsDifferentFromNoClass() {
        let model = WatchSchedule(schemaVersion: 1, updatedAt: 1, utcOffsetSeconds: 28800,
                                  semesterId: nil, semesterName: "", startDate: nil, endDate: nil, days: [])
        XCTAssertEqual(model.next(at: instant("07:00")), .noSemester)
    }
}
