import Foundation
import SwiftUI

/// 跟 Dart 侧 WidgetBridge 输出的 JSON 结构对齐。
struct TodayPayload: Decodable {
  let updatedAt: Int
  let weekLabel: String
  let dayLabel: String
  let semesterName: String
  let courses: [CourseItem]

  static let empty = TodayPayload(
    updatedAt: 0,
    weekLabel: "未设置学期",
    dayLabel: "",
    semesterName: "",
    courses: []
  )
}

struct CourseItem: Decodable, Identifiable {
  let id: String
  let name: String
  let teacher: String
  let location: String
  let startSection: Int
  let endSection: Int
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
      if let decoded = try? JSONDecoder().decode(TodayPayload.self, from: data) {
        return decoded
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
