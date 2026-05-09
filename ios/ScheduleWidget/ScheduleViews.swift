import SwiftUI
import WidgetKit

/// 构造点击课程后要跳的 URL。AppDelegate / SceneDelegate 会在打开时解析。
func courseDeepLink(_ id: String) -> URL? {
  URL(string: "schedule://course?id=\(id)")
}

// MARK: - Header ("我的课表 | 5.9 周六                       第 9 周")

struct ScheduleHeader: View {
  let payload: TodayPayload

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: 6) {
      Text("我的课表")
        .font(.system(size: 15, weight: .semibold))
        .foregroundStyle(.primary)
      Text("|")
        .font(.system(size: 14))
        .foregroundStyle(.secondary)
      if let d = payload.dateShort, !d.isEmpty {
        Text(d)
          .font(.system(size: 14, weight: .medium))
          .foregroundStyle(.primary)
      }
      if !payload.dayLabel.isEmpty {
        Text(payload.dayLabel)
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(Color(red: 1.0, green: 0.23, blue: 0.33))
      }
      Spacer()
      Text(payload.weekLabel)
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(.primary)
    }
  }
}

// MARK: - Empty state

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

// MARK: - Course row (参考图样式:左竖条 + 课名/教师 + 右侧双行时间)

struct CourseRow: View {
  let course: CourseItem
  let compact: Bool

  private var startTimeText: String {
    course.startTime ?? ""
  }
  private var endTimeText: String {
    course.endTime ?? ""
  }

  var body: some View {
    HStack(alignment: .center, spacing: 10) {
      RoundedRectangle(cornerRadius: 2)
        .fill(course.accentColor)
        .frame(width: 4)

      VStack(alignment: .leading, spacing: 2) {
        Text(course.name)
          .font(.system(size: compact ? 14 : 15, weight: .bold))
          .foregroundStyle(.primary)
          .lineLimit(1)
        let sub = [course.teacher, course.location]
          .filter { !$0.isEmpty }
          .joined(separator: " · ")
        if !sub.isEmpty {
          Text(sub)
            .font(.system(size: compact ? 11 : 12))
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
      }

      Spacer(minLength: 4)

      VStack(alignment: .trailing, spacing: 2) {
        if !startTimeText.isEmpty {
          Text(startTimeText)
            .font(.system(size: compact ? 13 : 14, weight: .semibold))
            .foregroundStyle(.primary)
            .monospacedDigit()
        }
        if !endTimeText.isEmpty {
          Text(endTimeText)
            .font(.system(size: compact ? 13 : 14, weight: .semibold))
            .foregroundStyle(.secondary)
            .monospacedDigit()
        }
      }
    }
    .padding(.horizontal, 10)
    .padding(.vertical, compact ? 8 : 10)
    .background(
      RoundedRectangle(cornerRadius: 14, style: .continuous)
        .fill(Color.black.opacity(0.22))
    )
  }
}

// MARK: - Small (2x2)

struct SmallScheduleView: View {
  let entry: ScheduleEntry

  private var next: CourseItem? { entry.payload.courses.first }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(alignment: .firstTextBaseline) {
        if !entry.payload.dayLabel.isEmpty {
          Text(entry.payload.dayLabel)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Color(red: 1.0, green: 0.23, blue: 0.33))
        }
        Spacer()
        Text(entry.payload.weekLabel)
          .font(.system(size: 11))
          .foregroundStyle(.secondary)
      }

      if let c = next, let url = courseDeepLink(c.id) {
        Link(destination: url) {
          CourseRow(course: c, compact: true)
        }
      } else {
        ScheduleEmpty()
      }
      Spacer(minLength: 0)
    }
  }
}

// MARK: - Medium (4x2) / Large (4x4)

struct ListScheduleView: View {
  let entry: ScheduleEntry
  let maxRows: Int

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      ScheduleHeader(payload: entry.payload)
      if entry.payload.courses.isEmpty {
        ScheduleEmpty()
      } else {
        VStack(spacing: 6) {
          ForEach(entry.payload.courses.prefix(maxRows)) { c in
            if let url = courseDeepLink(c.id) {
              Link(destination: url) {
                CourseRow(course: c, compact: maxRows > 3)
              }
            } else {
              CourseRow(course: c, compact: maxRows > 3)
            }
          }
        }
        Spacer(minLength: 0)
      }
    }
  }
}
