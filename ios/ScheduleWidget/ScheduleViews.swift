import SwiftUI
import WidgetKit

/// 构造点击课程后要跳的 URL。AppDelegate / SceneDelegate 会在打开时解析。
func courseDeepLink(_ id: String) -> URL? {
  URL(string: "schedule://course?id=\(id)")
}

// MARK: - Header

struct ScheduleHeader: View {
  let payload: TodayPayload

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: 6) {
      if let d = payload.dateShort, !d.isEmpty {
        Text(d)
          .font(.system(size: 15, weight: .semibold))
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
        .foregroundStyle(.secondary)
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

// MARK: - Course row (medium / large)

struct CourseRow: View {
  let course: CourseItem
  let compact: Bool

  private var timeText: String {
    let s = course.startTime ?? ""
    let e = course.endTime ?? ""
    if !s.isEmpty && !e.isEmpty { return "\(s) – \(e)" }
    if !s.isEmpty { return s }
    return course.sectionLabel
  }

  var body: some View {
    HStack(alignment: .center, spacing: 10) {
      VStack(alignment: .leading, spacing: 2) {
        Text(course.name)
          .font(.system(size: compact ? 14 : 15, weight: .bold))
          .foregroundStyle(.white)
          .lineLimit(1)
        let sub = [course.teacher, course.location]
          .filter { !$0.isEmpty }
          .joined(separator: " · ")
        if !sub.isEmpty {
          Text(sub)
            .font(.system(size: compact ? 11 : 12))
            .foregroundStyle(.white.opacity(0.85))
            .lineLimit(1)
        }
      }

      Spacer(minLength: 4)

      Text(timeText)
        .font(.system(size: compact ? 12 : 13, weight: .semibold))
        .foregroundStyle(.white.opacity(0.9))
        .monospacedDigit()
        .lineLimit(1)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, compact ? 8 : 10)
    .background(
      RoundedRectangle(cornerRadius: 12, style: .continuous)
        .fill(course.bgColor)
    )
  }
}

// MARK: - Small row (2x2 专用)

struct SmallCourseRow: View {
  let course: CourseItem

  var body: some View {
    HStack(alignment: .top, spacing: 6) {
      Circle()
        .fill(course.accentColor)
        .frame(width: 6, height: 6)
        .padding(.top, 5)
      VStack(alignment: .leading, spacing: 1) {
        Text(course.name)
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(.primary)
          .lineLimit(1)
        if !course.location.isEmpty {
          Text(course.location)
            .font(.system(size: 10))
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
      }
      Spacer(minLength: 4)
      if let t = course.startTime, !t.isEmpty {
        Text(t)
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(.primary)
          .monospacedDigit()
      }
    }
  }
}

// MARK: - Small (2x2)

struct SmallScheduleView: View {
  let entry: ScheduleEntry

  var body: some View {
    let shown = Array(entry.payload.upcomingCourses(now: entry.date).prefix(2))

    VStack(alignment: .leading, spacing: 6) {
      HStack(alignment: .firstTextBaseline) {
        if !entry.payload.dayLabel.isEmpty {
          Text(entry.payload.dayLabel)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Color(red: 1.0, green: 0.23, blue: 0.33))
        }
        Spacer()
        Text(entry.payload.weekLabel)
          .font(.system(size: 10))
          .foregroundStyle(.secondary)
      }

      if shown.isEmpty {
        ScheduleEmpty()
      } else {
        ForEach(Array(shown.enumerated()), id: \.element.id) { idx, c in
          if let url = courseDeepLink(c.id) {
            Link(destination: url) { SmallCourseRow(course: c) }
          } else {
            SmallCourseRow(course: c)
          }
          if idx < shown.count - 1 {
            Divider().opacity(0.2)
          }
        }
      }
      Spacer(minLength: 0)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
  }
}

// MARK: - Medium (4x2) / Large (4x4)

struct ListScheduleView: View {
  let entry: ScheduleEntry
  let maxRows: Int

  var body: some View {
    let shown = Array(entry.payload.upcomingCourses(now: entry.date).prefix(maxRows))

    VStack(alignment: .leading, spacing: 10) {
      ScheduleHeader(payload: entry.payload)
      if shown.isEmpty {
        ScheduleEmpty()
      } else {
        VStack(spacing: 6) {
          ForEach(shown) { c in
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
    .padding(.horizontal, 14)
    .padding(.vertical, 12)
  }
}
