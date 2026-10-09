import Foundation
import SwiftUI
import os

/// 跟 Dart 侧 WidgetBridge 输出的 JSON 结构对齐。
struct TodayPayload: Decodable {
  let updatedAt: Int
  let weekLabel: String
  let dayLabel: String
  let dateShort: String?
  let semesterName: String
  let courses: [CourseItem]
  let tomorrowCourses: [CourseItem]

  private enum CodingKeys: String, CodingKey { case updatedAt, weekLabel, dayLabel, dateShort, semesterName, courses, tomorrowCourses }

  init(from decoder: Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    updatedAt = try c.decode(Int.self, forKey: .updatedAt)
    weekLabel = try c.decode(String.self, forKey: .weekLabel)
    dayLabel = try c.decode(String.self, forKey: .dayLabel)
    dateShort = try c.decodeIfPresent(String.self, forKey: .dateShort)
    semesterName = try c.decode(String.self, forKey: .semesterName)
    courses = try c.decode([CourseItem].self, forKey: .courses)
    tomorrowCourses = try c.decodeIfPresent([CourseItem].self, forKey: .tomorrowCourses) ?? []
  }

  init(updatedAt: Int, weekLabel: String, dayLabel: String, dateShort: String?, semesterName: String, courses: [CourseItem], tomorrowCourses: [CourseItem]) {
    self.updatedAt = updatedAt; self.weekLabel = weekLabel; self.dayLabel = dayLabel
    self.dateShort = dateShort; self.semesterName = semesterName; self.courses = courses
    self.tomorrowCourses = tomorrowCourses
  }

  static let empty = TodayPayload(
    updatedAt: 0,
    weekLabel: "未设置学期",
    dayLabel: "",
    dateShort: nil,
    semesterName: "",
    courses: [],
    tomorrowCourses: []
  )

  /// 今日剩余课程:endTime(HH:mm)解析后 >= now 才留。
  /// 解析失败的 defensive 保留,避免旧数据突然掉课。
  func upcomingCourses(now: Date = Date()) -> [CourseItem] {
    let cal = Calendar.current
    let comps = cal.dateComponents([.year, .month, .day], from: now)
    return courses.filter { c in
      guard let end = c.endTime, !end.isEmpty else { return true }
      let parts = end.split(separator: ":").compactMap { Int($0) }
      guard parts.count == 2 else { return true }
      var dc = comps
      dc.hour = parts[0]
      dc.minute = parts[1]
      guard let endDate = cal.date(from: dc) else { return true }
      return endDate >= now
    }
  }
}

struct CourseItem: Decodable, Identifiable {
  let id: String
  let name: String
  let teacher: String
  let location: String
  let startSection: Int
  let endSection: Int
  let startTime: String?
  let endTime: String?
  let colorBg: String
  let colorAccent: String

  var sectionLabel: String { "第 \(startSection)-\(endSection) 节" }

  var bgColor: Color { Color(hex: colorBg) ?? Color(.systemGray6) }
  var accentColor: Color { Color(hex: colorAccent) ?? .accentColor }
}

enum PayloadStore {
  static let appGroup = "group.com.jlu.schedule"
  static let key = "today_payload"

  /// home_widget 插件写入时 key 是原样的,但某些版本会加前缀。
  /// 两种都尝试一遍,保证能读到。
  private static let candidateKeys = [key, "flutter.\(key)"]

  static func load() -> TodayPayload {
    guard let defaults = UserDefaults(suiteName: appGroup) else {
      return .empty
    }
    for k in candidateKeys {
      guard let raw = defaults.string(forKey: k),
            let data = raw.data(using: .utf8) else { continue }
      do {
        return try JSONDecoder().decode(TodayPayload.self, from: data)
      } catch {
        #if DEBUG
        os_log(.error, "ScheduleWidget: JSON decode failed for key %{public}@: %{public}@",
               k, String(describing: error))
        #endif
      }
    }
    return .empty
  }
}

extension Color {
  /// 支持 "#AARRGGBB" / "#RRGGBB"。
  init?(hex: String) {
    var s = hex
    if s.hasPrefix("#") { s.removeFirst() }
    guard let v = UInt64(s, radix: 16) else { return nil }
    let a, r, g, b: Double
    switch s.count {
    case 8:
      a = Double((v >> 24) & 0xff) / 255
      r = Double((v >> 16) & 0xff) / 255
      g = Double((v >> 8) & 0xff) / 255
      b = Double(v & 0xff) / 255
    case 6:
      a = 1
      r = Double((v >> 16) & 0xff) / 255
      g = Double((v >> 8) & 0xff) / 255
      b = Double(v & 0xff) / 255
    default:
      return nil
    }
    self = Color(.sRGB, red: r, green: g, blue: b, opacity: a)
  }
}
