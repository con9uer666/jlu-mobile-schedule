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
    completion(ScheduleEntry(date: Date(), payload: PayloadStore.load()))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<ScheduleEntry>) -> Void) {
    let now = Date()
    let entry = ScheduleEntry(date: now, payload: PayloadStore.load())
    // 15 分钟刷一次兜底;Dart 侧数据变化时会主动 reloadAllTimelines。
    // 小粒度是为了配合"已下课则消失"的过滤逻辑。
    let next = Calendar.current.date(byAdding: .minute, value: 15, to: now) ?? now.addingTimeInterval(900)
    completion(Timeline(entries: [entry], policy: .after(next)))
  }
}
