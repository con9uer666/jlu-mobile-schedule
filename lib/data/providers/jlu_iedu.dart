import '../raw_entry.dart';
import '../school_provider.dart';

/// 吉林大学 iedu(jwapp 智慧校园那一套)。
/// 关键点:session cookie 是 HttpOnly,Dart 端拿不到,所以直接在 WebView
/// 里 fetch 同源接口,cookie 自动附带。
class JluIeduProvider extends SchoolProvider {
  const JluIeduProvider();

  @override
  String get id => 'jlu-iedu';

  @override
  String get displayName => '吉林大学 iedu';

  @override
  String get entryUrl =>
      'https://iedu.jlu.edu.cn/jwapp/sys/wdkb/*default/index.do?THEME=indigo&EMAP_LANG=zh';

  // 登录会跳到 cas.jlu.edu.cn(TPass 统一身份认证),放行整个 jlu.edu.cn 根域。
  @override
  String get trustRootHost => 'jlu.edu.cn';

  @override
  String get userAgent =>
      'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) '
      'AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148';

  @override
  bool isLoggedIn(String url) {
    if (!url.contains('iedu.jlu.edu.cn')) return false;
    return url.contains('/jwapp/sys/wdkb/');
  }

  @override
  String get fetcherScript => _fetcherScript;

  @override
  List<CourseRawEntry> parseRows(List<Map> rows) {
    final out = <CourseRawEntry>[];
    for (final row in rows) {
      final name = row['KCM'] as String? ?? '';
      if (name.isEmpty) continue;
      final dayOfWeek = (row['SKXQ'] as num?)?.toInt() ?? 0;
      final startSection = (row['KSJC'] as num?)?.toInt() ?? 0;
      final endSection = (row['JSJC'] as num?)?.toInt() ?? startSection;
      if (dayOfWeek == 0 || startSection == 0) continue;
      final mask = row['SKZC'] as String? ?? '';
      final weeks = <int>[];
      for (var i = 0; i < mask.length; i++) {
        if (mask[i] == '1') weeks.add(i + 1);
      }
      if (weeks.isEmpty) continue;
      out.add(CourseRawEntry(
        name: name,
        teacher: row['SKJS'] as String? ?? '',
        location: row['JASMC'] as String? ?? '',
        dayOfWeek: dayOfWeek,
        startSection: startSection,
        endSection: endSection,
        weeks: weeks,
      ));
    }
    return out;
  }

  static const _fetcherScript = r'''
(async () => {
  const post = async (path, body) => {
    const r = await fetch(path, {
      method: 'POST',
      credentials: 'include',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
        'X-Requested-With': 'XMLHttpRequest',
      },
      body: body || '',
    });
    if (!r.ok) throw new Error(path + ' HTTP ' + r.status);
    const j = await r.json();
    if (j.code !== '0' && j.code !== 0) {
      throw new Error(path + ' code=' + j.code);
    }
    return j;
  };
  try {
    const term = await post('/jwapp/sys/wdkb/modules/jshkcb/dqxnxq.do');
    const termRow = ((term.datas || {}).dqxnxq || {}).rows || [];
    if (!termRow.length) throw new Error('dqxnxq 空');
    const xnxqdm = termRow[0].DM;
    const termName = termRow[0].MC || '';
    const parts = xnxqdm.split('-');
    if (parts.length < 3) throw new Error('xnxqdm 格式 ' + xnxqdm);
    const xn = parts[0] + '-' + parts[1];
    const xq = parts[2];

    const meta = await post(
      '/jwapp/sys/wdkb/modules/jshkcb/cxjcs.do',
      'XN=' + encodeURIComponent(xn) + '&XQ=' + encodeURIComponent(xq)
    );
    const metaRow = ((meta.datas || {}).cxjcs || {}).rows || [];
    if (!metaRow.length) throw new Error('cxjcs 空');
    const ksrq = metaRow[0].XQKSRQ;
    const zzc = metaRow[0].ZZC;

    const sch = await post(
      '/jwapp/sys/wdkb/modules/xskcb/cxxszhxqkb.do',
      'XNXQDM=' + encodeURIComponent(xnxqdm)
    );
    const rows = ((sch.datas || {}).cxxszhxqkb || {}).rows || [];

    JwappBridge.postMessage(JSON.stringify({
      ok: true,
      xnxqdm: xnxqdm,
      termName: termName,
      startDate: ksrq,
      totalWeeks: zzc,
      rows: rows,
    }));
  } catch (e) {
    JwappBridge.postMessage(JSON.stringify({
      ok: false,
      error: (e && e.message) ? e.message : String(e),
    }));
  }
})();
''';
}
