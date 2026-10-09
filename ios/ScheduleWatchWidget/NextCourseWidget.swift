import SwiftUI
import WidgetKit

struct WatchCourseEntry: TimelineEntry {
    let date: Date
    let next: WatchNextCourse?
}

struct WatchCourseProvider: TimelineProvider {
    func placeholder(in context: Context) -> WatchCourseEntry {
        WatchCourseEntry(date: .now, next: .course(
            WatchCourse(id: "preview", name: "高等数学", location: "第一教学楼 302", startTime: "10:00", endTime: "11:40"),
            tomorrow: false
        ))
    }
    func getSnapshot(in context: Context, completion: @escaping (WatchCourseEntry) -> Void) {
        if context.isPreview { completion(placeholder(in: context)); return }
        completion(WatchCourseEntry(date: .now, next: WatchScheduleStore.load()?.next(at: .now)))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<WatchCourseEntry>) -> Void) {
        let now = Date()
        guard let schedule = WatchScheduleStore.load() else {
            completion(Timeline(entries: [WatchCourseEntry(date: now, next: nil)], policy: .after(now.addingTimeInterval(900))))
            return
        }
        let entries = schedule.transitionDates(after: now).map {
            WatchCourseEntry(date: $0, next: schedule.next(at: $0))
        }
        completion(Timeline(entries: entries, policy: .after(now.addingTimeInterval(6 * 3600))))
    }
}

struct WatchCourseComplicationView: View {
    let entry: WatchCourseEntry
    var body: some View {
        Group {
            switch entry.next {
            case .course(let course, let tomorrow):
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(tomorrow ? "明天" : "下一节")
                        Text(course.startTime).monospacedDigit()
                    }
                    .font(.caption).fontWeight(.semibold).widgetAccentable()
                    Text(course.name).font(.headline).lineLimit(1).minimumScaleFactor(0.85)
                    Text(course.location.isEmpty ? "教室未填写" : course.location)
                        .font(.caption2).lineLimit(1)
                }
            case .noClassTomorrow:
                empty(title: "明天无课", subtitle: "点击查看今天课表")
            case .noSemester:
                empty(title: "未设置学期", subtitle: "请在 iPhone 上设置")
            case nil:
                empty(title: "课表待同步", subtitle: "打开 iPhone 和手表课程表")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .clipped()
        .containerBackground(.clear, for: .widget)
        .widgetURL(URL(string: "schedulewatch://today"))
        .accessibilityElement(children: .combine)
    }
    private func empty(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Label("课程表", systemImage: "calendar").font(.caption).widgetAccentable()
            Text(title).font(.headline)
            Text(subtitle).font(.caption2).lineLimit(1).minimumScaleFactor(0.8)
        }
    }
}

@main
struct NextCourseWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WatchScheduleStore.widgetKind, provider: WatchCourseProvider()) { entry in
            WatchCourseComplicationView(entry: entry)
        }
        .configurationDisplayName("下一节课")
        .description("显示下一节课的时间、名称和教室。点击查看今天课表。")
        .supportedFamilies([.accessoryRectangular])
    }
}
