import 'raw_entry.dart';

/// 学校教务适配器。每个学校一份实现,导入流程根据选中的 provider
/// 去驱动 WebView、注入抓取脚本、解析返回 rows。
///
/// WebView 侧执行 [fetcherScript] 时,必须通过 `JwappBridge.postMessage`
/// 回传统一结构的 JSON:
///
/// 成功:
/// {
///   "ok": true,
///   "xnxqdm":    String,   // 学期唯一 id,内部 Semester.id 就取它
///   "termName":  String,   // 人类可读学期名,空串也行
///   "startDate": String,   // "YYYY-MM-DD",第一教学周的周一
///   "totalWeeks": int,     // 学期总周数
///   "rows":      List<Map> // 原始课表行,交给 [parseRows] 翻译
/// }
///
/// 失败:
/// { "ok": false, "error": String }
///
/// 保持这个契约,上层 [ImportPage] 就完全不用知道具体学校。
abstract class SchoolProvider {
  const SchoolProvider();

  /// 唯一 id,用作存 prefs 默认值和以后迁移识别。
  String get id;

  /// 展示在"选择学校"列表里的名字。
  String get displayName;

  /// 登录入口 URL。WebView 直接加载。
  String get entryUrl;

  /// 证书放行的根域。统一身份认证登录常会从入口域跳到同校的 SSO/CAS 子域
  /// (如 iedu.jlu.edu.cn → cas.jlu.edu.cn),这些子域若用学校私有 CA,会触发
  /// WebView 的服务器信任挑战。放行该根域及其所有子域即可覆盖整条登录链路。
  /// 默认只放行入口域名本身;各校按需放宽到根域。
  String get trustRootHost => Uri.parse(entryUrl).host;

  /// WebView UA。有些教务对 PC UA 会返回不同页面,交给 provider 决定。
  String get userAgent;

  /// 判断 WebView 当前 URL 是否已经进入"已登录、可抓取"的状态。
  /// 返回 true 后才会注入 [fetcherScript]。
  bool isLoggedIn(String currentUrl);

  /// 注入到 WebView 的抓取脚本,必须遵守上面声明的回传结构。
  String get fetcherScript;

  /// 把 fetcher 吐回来的原始 rows 翻译成统一的 [CourseRawEntry] 列表。
  /// 各校字段名不同,这一步吃掉差异。
  List<CourseRawEntry> parseRows(List<Map> rows);

  /// 学期 sectionCount 的下限建议。若课表数据里没覆盖到晚课(例如只有白天
  /// 的课),仍要保证格子数够用。默认 12(一天 12 小节的通用刻度)。
  int get minSectionCount => 12;
}
