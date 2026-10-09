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
    .description("突出显示下一节课和接下来的课程")
    .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    .contentMarginsDisabled()
  }
}

struct ScheduleWidgetEntryView: View {
  @Environment(\.widgetFamily) var family
  let entry: ScheduleEntry

  var body: some View {
    Group {
      switch family {
      case .systemSmall:
        SmallScheduleView(entry: entry)
      case .systemMedium:
        MediumScheduleView(entry: entry)
      default:
        ListScheduleView(entry: entry, maxRows: 5)
      }
    }
    .clipped()
  }
}

extension View {
  @ViewBuilder
  func widgetBackground() -> some View {
    if #available(iOS 17.0, *) {
      self.containerBackground(for: .widget) {
        Color(UIColor { $0.userInterfaceStyle == .dark ? .black : .white })
      }
    } else {
      self.background(Color(.systemBackground))
    }
  }
}

@main
struct ScheduleWidgetBundle: WidgetBundle {
  var body: some Widget {
    ScheduleWidget()
  }
}
