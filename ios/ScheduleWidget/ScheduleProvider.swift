import WidgetKit
import SwiftUI

struct ScheduleEntry: TimelineEntry {
  let date: Date
  let payload: TodayPayload
}

struct ScheduleProvider: TimelineProvider {
  func placeholder(in context: Context) -> ScheduleEntry {
    ScheduleEntry(date: Date(), payload: .empty)
  }

  func getSnapshot(in context: Context, completion: @escaping (ScheduleEntry) -> Void) {
    completion(ScheduleEntry(date: Date(), payload: PayloadStore.load().forDate(Date())))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<ScheduleEntry>) -> Void) {
    let now = Date()
    let cal = Calendar.current
    let cached = PayloadStore.load()
    var dates = Set<Date>([now])
    // Schedule midnight and class endings explicitly, without depending on a
    // frequent background wake-up or on opening the phone app each morning.
    for offset in 0...7 {
      guard let day = cal.date(byAdding: .day, value: offset, to: cal.startOfDay(for: now)) else { continue }
      if day > now { dates.insert(day) }
      for course in cached.forDate(day).courses {
        let parts = (course.endTime ?? "").split(separator: ":").compactMap { Int($0) }
        if parts.count == 2,
           let end = cal.date(bySettingHour: parts[0], minute: parts[1], second: 1, of: day), end > now {
          dates.insert(end)
        }
      }
    }
    let entries = dates.sorted().map { ScheduleEntry(date: $0, payload: cached.forDate($0)) }
    completion(Timeline(entries: entries, policy: .atEnd))
  }
}
