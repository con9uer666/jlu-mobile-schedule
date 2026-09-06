import SwiftUI
import WidgetKit

func courseDeepLink(_ id: String) -> URL? {
  var comps = URLComponents()
  comps.scheme = "schedule"
  comps.host = "course"
  comps.queryItems = [URLQueryItem(name: "id", value: id)]
  return comps.url
}

// MARK: - Header

struct ScheduleHeader: View {
  let payload: TodayPayload

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: 6) {
      if let d = payload.dateShort, !d.isEmpty {
        Text(d)
          .font(.system(size: 15, weight: .semibold))
          .foregroundStyle(Color.primary)
      }
      if !payload.dayLabel.isEmpty {
        Text(payload.dayLabel)
          .font(.system(size: 14, weight: .semibold))
          .foregroundStyle(Color(red: 1.0, green: 0.23, blue: 0.18))
      }
      Spacer()
      Text(payload.weekLabel)
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(Color.secondary)
    }
  }
}

// MARK: - Empty state

struct ScheduleEmpty: View {
  var body: some View {
    Text("今天没课")
      .font(.system(size: 13))
      .foregroundStyle(Color.secondary)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

// MARK: - Course row (medium / large)

struct CourseRow: View {
  let course: CourseItem
  let compact: Bool

  var body: some View {
    HStack(alignment: .center, spacing: 0) {
      RoundedRectangle(cornerRadius: 2, style: .continuous)
        .fill(course.accentColor)
        .frame(width: 4)
        .padding(.vertical, compact ? 6 : 8)
        .padding(.leading, 8)

      HStack(alignment: .center, spacing: 10) {
        VStack(alignment: .leading, spacing: 2) {
          Text(course.name)
            .font(.system(size: compact ? 14 : 15, weight: .bold))
            .foregroundStyle(Color.primary)
            .lineLimit(1)
          let sub = [course.teacher, course.location]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
          if !sub.isEmpty {
            Text(sub)
              .font(.system(size: compact ? 11 : 12))
              .foregroundStyle(Color.secondary)
              .lineLimit(1)
          }
        }

        Spacer(minLength: 4)

        VStack(alignment: .trailing, spacing: 1) {
          Text(course.startTime ?? course.sectionLabel)
            .font(.system(size: compact ? 12 : 13, weight: .bold))
            .foregroundStyle(Color.primary)
            .monospacedDigit()
          if let end = course.endTime, !end.isEmpty {
            Text(end)
              .font(.system(size: compact ? 12 : 13, weight: .bold))
              .foregroundStyle(Color.secondary)
              .monospacedDigit()
          }
        }
        .lineLimit(1)
      }
      .padding(.leading, 10)
      .padding(.trailing, 12)
      .padding(.vertical, compact ? 8 : 10)
    }
    .background(courseBackground)
  }

  @ViewBuilder
  private var courseBackground: some View {
    // iOS 的 .tertiarySystemFill 在 macOS 上不存在,用同色调的 RGB 硬编码。
    RoundedRectangle(cornerRadius: 12, style: .continuous)
      .fill(Color(red: 0.46, green: 0.46, blue: 0.5, opacity: 0.12))
  }
}

// MARK: - Small row (2x2 专用)

struct SmallCourseRow: View {
  let course: CourseItem

  var body: some View {
    HStack(alignment: .center, spacing: 6) {
      Circle()
        .fill(course.accentColor)
        .frame(width: 6, height: 6)
      VStack(alignment: .leading, spacing: 1) {
        Text(course.name)
          .font(.system(size: 12, weight: .semibold))
          .foregroundStyle(Color.primary)
          .lineLimit(2)
          .fixedSize(horizontal: false, vertical: true)
        HStack(spacing: 0) {
          if !course.location.isEmpty {
            Text(course.location)
              .font(.system(size: 10))
              .foregroundStyle(Color.secondary)
              .lineLimit(1)
          }
          Spacer(minLength: 4)
          if let t = course.startTime, !t.isEmpty {
            Text(t)
              .font(.system(size: 10, weight: .medium))
              .foregroundStyle(Color.secondary)
              .monospacedDigit()
          }
        }
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
            .foregroundStyle(Color(red: 1.0, green: 0.23, blue: 0.18))
        }
        Spacer()
        Text(entry.payload.weekLabel)
          .font(.system(size: 10))
          .foregroundStyle(Color.secondary)
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
            Divider().opacity(0.3)
          }
        }
        Spacer(minLength: 0)
      }
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 8)
  }
}

// MARK: - Medium (4x2) / Large (4x4)

struct ListScheduleView: View {
  let entry: ScheduleEntry
  let maxRows: Int

  var body: some View {
    let shown = Array(entry.payload.upcomingCourses(now: entry.date).prefix(maxRows))

    VStack(alignment: .leading, spacing: 0) {
      ScheduleHeader(payload: entry.payload)
      if shown.isEmpty {
        Spacer(minLength: 0)
        ScheduleEmpty()
        Spacer(minLength: 0)
      } else {
        Spacer(minLength: 6)
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
        Spacer(minLength: 6)
      }
    }
    .padding(.horizontal, 14)
    .padding(.top, 14)
    .padding(.bottom, 10)
  }
}
