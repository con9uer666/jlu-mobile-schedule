import 'dart:convert';
import 'dart:io';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';

import '../data/raw_entry.dart';

/// 吉林大学 jwapp(iedu.jlu.edu.cn)课表抓取客户端。
///
/// 登录流程走 WebView(见 [JlujwappLoginPage]),本类只负责拿到 cookie 后
/// 调用业务接口。
class JlujwappClient {
  JlujwappClient({List<Cookie>? cookies}) {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        followRedirects: true,
        validateStatus: (s) => s != null && s < 500,
        headers: {
          'User-Agent':
              'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148',
          'X-Requested-With': 'XMLHttpRequest',
          'Referer':
              '$baseUrl/jwapp/sys/wdkb/*default/index.do?THEME=indigo&EMAP_LANG=zh',
          'Origin': baseUrl,
        },
      ),
    );
    _dio.interceptors.add(CookieManager(_jar));
    _dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final c = HttpClient();
        c.badCertificateCallback = (cert, host, port) {
          return host == 'iedu.jlu.edu.cn';
        };
        return c;
      },
    );
    if (cookies != null) {
      _jar.saveFromResponse(Uri.parse(baseUrl), cookies);
    }
  }

  static const baseUrl = 'https://iedu.jlu.edu.cn';

  late final Dio _dio;
  final CookieJar _jar = CookieJar();

  /// 通过 WebView 拿到的 cookie 写进 jar。
  Future<void> setCookies(List<Cookie> cookies) =>
      _jar.saveFromResponse(Uri.parse(baseUrl), cookies);

  Map<String, dynamic> _unwrap(Response r, String dataKey) {
    if (r.statusCode != 200) {
      throw JwappException('HTTP ${r.statusCode}');
    }
    final data = r.data is String ? jsonDecode(r.data as String) : r.data;
    if (data is! Map) throw JwappException('返回不是 JSON 对象');
    final code = data['code'];
    if (code != '0' && code != 0) {
      throw JwappException('接口 code=$code,可能登录失效,请重新登录');
    }
    final inner = (data['datas'] as Map?)?[dataKey];
    if (inner is! Map) throw JwappException('返回缺少 datas.$dataKey');
    final ext = inner['extParams'];
    if (ext is Map && ext['code'] != 1) {
      throw JwappException('$dataKey 失败: ${ext['msg']}');
    }
    return Map<String, dynamic>.from(inner);
  }

  /// 获取当前学年学期代码,如 `2025-2026-2`。
  Future<({String xnxqdm, String name})> fetchCurrentTerm() async {
    final r = await _dio.post('/jwapp/sys/wdkb/modules/jshkcb/dqxnxq.do');
    final inner = _unwrap(r, 'dqxnxq');
    final rows = inner['rows'] as List;
    if (rows.isEmpty) throw JwappException('dqxnxq 无数据');
    final row = rows.first as Map;
    return (
      xnxqdm: row['DM'] as String,
      name: (row['MC'] as String?) ?? '',
    );
  }

  /// 获取学期开始日期、总周数。
  Future<({DateTime startDate, int totalWeeks})> fetchTermMeta({
    required String xn,
    required String xq,
  }) async {
    final r = await _dio.post(
      '/jwapp/sys/wdkb/modules/jshkcb/cxjcs.do',
      data: 'XN=$xn&XQ=$xq',
    );
    final inner = _unwrap(r, 'cxjcs');
    final rows = inner['rows'] as List;
    if (rows.isEmpty) throw JwappException('cxjcs 无数据');
    final row = rows.first as Map;
    final ksrq = row['XQKSRQ'] as String;
    final start = DateTime.parse(ksrq.split(' ').first);
    final zzc = row['ZZC'];
    final total = zzc is int ? zzc : int.parse('$zzc');
    return (startDate: start, totalWeeks: total);
  }

  /// 获取整学期课表。
  Future<JwappFetchResult> fetchSchedule({required String xnxqdm}) async {
    final r = await _dio.post(
      '/jwapp/sys/wdkb/modules/xskcb/cxxszhxqkb.do',
      data: 'XNXQDM=$xnxqdm',
    );
    final inner = _unwrap(r, 'cxxszhxqkb');
    final rows = (inner['rows'] as List).cast<Map>();
    final entries = <CourseRawEntry>[];
    for (final row in rows) {
      final name = row['KCM'] as String? ?? '';
      if (name.isEmpty) continue;
      final teacher = row['SKJS'] as String? ?? '';
      final location = row['JASMC'] as String? ?? '';
      final dayOfWeek = (row['SKXQ'] as num?)?.toInt() ?? 0;
      final startSection = (row['KSJC'] as num?)?.toInt() ?? 0;
      final endSection = (row['JSJC'] as num?)?.toInt() ?? startSection;
      if (dayOfWeek == 0 || startSection == 0) continue;
      final weeksMask = row['SKZC'] as String? ?? '';
      final weeks = _parseWeekMask(weeksMask);
      if (weeks.isEmpty) continue;
      entries.add(CourseRawEntry(
        name: name,
        teacher: teacher,
        location: location,
        dayOfWeek: dayOfWeek,
        startSection: startSection,
        endSection: endSection,
        weeks: weeks,
      ));
    }
    return JwappFetchResult(
      entries: entries,
      semesterName: null,
    );
  }

  /// SKZC 是形如 "11110111000..." 的位掩码,第 i 位为 1 表示第 i+1 周有课。
  static List<int> _parseWeekMask(String mask) {
    final out = <int>[];
    for (var i = 0; i < mask.length; i++) {
      if (mask[i] == '1') out.add(i + 1);
    }
    return out;
  }
}
