import SwiftUI
import WidgetKit

/// 构造点击课程后要跳的 URL。AppDelegate 会在 application(_:open:) 里解析。
func courseDeepLink(_ id: String) -> URL? {
  URL(string: "schedule://course?id=\(id)")
}

struct ScheduleHeader: View {
  let payload: TodayPayload

  var body: some View {
    HStack(alignment: .firstTextBaseline) {
      Text(payload.dayLabel.isEmpty ? "今日课表" : payload.dayLabel)
        .font(.system(size: 15, weight: .semibold))
      Spacer()
      Text(payload.weekLabel)
        .font(.system(size: 12))
        .foregroundStyle(.secondary)
    }
  }
}

struct ScheduleEmpty: View {
  var body: some View {
    VStack(spacing: 6) {
      Image(systemName: "moon.zzz")
        .font(.system(size: 22))
        .foregroundStyle(.secondary)
      Text("今日无课")
        .font(.system(size: 13))
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

struct CourseRow: View {
  let course: CourseItem
  let compact: Bool

  var body: some View {
    HStack(alignment: .center, spacing: 8) {
      RoundedRectangle(cornerRadius: 1.5)
        .fill(course.accentColor)
        .frame(width: 3)
      VStack(alignment: .leading, spacing: 2) {
        Text(course.name)
          .font(.system(size: compact ? 12 : 13, weight: .semibold))
          .foregroundStyle(course.accentColor)
          .lineLimit(1)
        HStack(spacing: 6) {
          Text(course.sectionLabel)
            .font(.system(size: 10))
            .foregroundStyle(.secondary)
          if !course.location.isEmpty {
            Text(course.location)
              .font(.system(size: 10))
              .foregroundStyle(.secondary)
              .lineLimit(1)
          }
        }
      }
      Spacer(minLength: 0)
    }
    .padding(.horizontal, 8)
    .padding(.vertical, compact ? 4 : 6)
    .background(
      RoundedRectangle(cornerRadius: 8)
        .fill(course.bgColor)
    )
    .widgetURL(courseDeepLink(course.id))
  }
}

// MARK: - Small (2x2): 只显示"下一节"

struct SmallScheduleView: View {
  let entry: ScheduleEntry

  private var next: CourseItem? { entry.payload.courses.first }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      ScheduleHeader(payload: entry.payload)
      if let c = next {
        VStack(alignment: .leading, spacing: 4) {
          Text(c.name)
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(c.accentColor)
            .lineLimit(2)
          Text(c.sectionLabel)
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
          if !c.location.isEmpty {
            Text(c.location)
              .font(.system(size: 11))
              .foregroundStyle(.secondary)
              .lineLimit(1)
          }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
          RoundedRectangle(cornerRadius: 10)
            .fill(c.bgColor)
        )
        .widgetURL(courseDeepLink(c.id))
      } else {
        ScheduleEmpty()
      }
      Spacer(minLength: 0)
    }
  }
}

// MARK: - Medium (4x2) / Large (4x4): 列表

struct ListScheduleView: View {
  let entry: ScheduleEntry
  let maxRows: Int

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      ScheduleHeader(payload: entry.payload)
      if entry.payload.courses.isEmpty {
        ScheduleEmpty()
      } else {
        VStack(spacing: 4) {
          ForEach(entry.payload.courses.prefix(maxRows)) { c in
            CourseRow(course: c, compact: maxRows <= 3)
          }
        }
        Spacer(minLength: 0)
      }
    }
  }
}
