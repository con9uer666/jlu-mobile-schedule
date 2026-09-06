import WidgetKit
import SwiftUI

struct ScheduleWidget: Widget {
  let kind: String = "ScheduleWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: ScheduleProvider()) { entry in
      ScheduleWidgetEntryView(entry: entry)
        .widgetBackground()
    }
    .configurationDisplayName("课程表")
    .description("显示今天的课程")
    .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
  }
}

struct ScheduleWidgetEntryView: View {
  @Environment(\.widgetFamily) var family
  let entry: ScheduleEntry

  var body: some View {
    switch family {
    case .systemSmall:
      SmallScheduleView(entry: entry)
    case .systemMedium:
      ListScheduleView(entry: entry, maxRows: 2)
    default:
      ListScheduleView(entry: entry, maxRows: 5)
    }
  }
}

extension View {
  @ViewBuilder
  func widgetBackground() -> some View {
    if #available(macOS 14.0, *) {
      self.containerBackground(for: .widget) {
        Color("WidgetBackground")
      }
    } else {
      self.background(Color("WidgetBackground"))
    }
  }
}

@main
struct ScheduleWidgetBundle: WidgetBundle {
  var body: some Widget {
    ScheduleWidget()
  }
}
