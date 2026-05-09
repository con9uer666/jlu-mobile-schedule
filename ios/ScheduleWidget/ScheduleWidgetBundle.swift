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
      ListScheduleView(entry: entry, maxRows: 3)
    default:
      ListScheduleView(entry: entry, maxRows: 6)
    }
  }
}

/// iOS 17+:用透明 containerBackground,让 iOS 26 的 Liquid Glass 渲染起作用。
/// 真正的"深色玻璃"底是在内容层用半透明材质叠出来的,避免挡住系统玻璃层。
extension View {
  @ViewBuilder
  func widgetBackground() -> some View {
    if #available(iOS 17.0, *) {
      self.containerBackground(for: .widget) {
        Color.clear
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
