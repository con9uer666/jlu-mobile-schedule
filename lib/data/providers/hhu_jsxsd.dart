import '../raw_entry.dart';
import '../school_provider.dart';

/// 河海大学教务(jwxt.hhu.edu.cn,强智 jsxsd 系列)。
///
/// jsxsd 的课表页 `/jsxsd/xskb/xskb_list.do` 直接返回渲染好的 HTML,没有 JSON 接口。
/// 我们在 WebView 里同源 fetch 这个 HTML,用 DOMParser 解析出每门课。
///
/// 节次布局(河海五大节制,实际 12 小节):
///   第一大节 1-2 小节   08:00-09:35
///   第二大节 3-5 小节   09:50-12:15
///   第三大节 6-7 小节   14:00-15:35
///   第四大节 8-9 小节   15:50-17:25
///   第五大节 10-12 小节 18:30-20:55
/// 课程 `<font title='周次(节次)'>` 文本形如 `9-17(周)[1-2节]` / `9-18(周)[3-4-5节]`,
/// 我们取首末数字当 startSection / endSection,节次数 = 12 个。
///
/// 开学日期 jsxsd 页面里没带,HTML 也没给;先用"xnxq01id + 启发式月份"
/// 估一个临近周一,精确值由用户在学期设置页调整(这是项目已有的兜底路径)。
class HhuJsxsdProvider extends SchoolProvider {
  const HhuJsxsdProvider();

  @override
  String get id => 'hhu-jsxsd';

  @override
  String get displayName => '河海大学教务';

  @override
  String get entryUrl => 'https://jwxt.hhu.edu.cn/jsxsd/';

  @override
  String get userAgent =>
      'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) '
      'AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148';

  @override
  bool isLoggedIn(String url) {
    if (!url.contains('jwxt.hhu.edu.cn')) return false;
    return url.contains('/jsxsd/framework/') ||
        url.contains('/jsxsd/grsz/') ||
        url.contains('/jsxsd/xskb/');
  }

  @override
  String get fetcherScript => _fetcherScript;

  @override
  List<CourseRawEntry> parseRows(List<Map> rows) {
    final out = <CourseRawEntry>[];
    for (final row in rows) {
      final name = (row['name'] as String?) ?? '';
      if (name.isEmpty) continue;
      final dow = (row['dayOfWeek'] as num?)?.toInt() ?? 0;
      final start = (row['startSection'] as num?)?.toInt() ?? 0;
      final end = (row['endSection'] as num?)?.toInt() ?? start;
      if (dow == 0 || start == 0) continue;
      final weeksRaw = row['weeks'];
      final weeks = weeksRaw is List
          ? weeksRaw.map((e) => (e as num).toInt()).toList()
          : const <int>[];
      if (weeks.isEmpty) continue;
      out.add(CourseRawEntry(
        name: name,
        teacher: (row['teacher'] as String?) ?? '',
        location: (row['location'] as String?) ?? '',
        dayOfWeek: dow,
        startSection: start,
        endSection: end,
        weeks: weeks,
      ));
    }
    return out;
  }

  static const _fetcherScript = r'''
(async () => {
  const report = (obj) => JwappBridge.postMessage(JSON.stringify(obj));
  try {
    const r = await fetch('/jsxsd/xskb/xskb_list.do', {
      method: 'GET',
      credentials: 'include',
      headers: { 'X-Requested-With': 'XMLHttpRequest' },
    });
    if (!r.ok) throw new Error('xskb_list HTTP ' + r.status);
    const html = await r.text();
    const doc = new DOMParser().parseFromString(html, 'text/html');

    // —— 学期 id ——
    let xnxqdm = '';
    const sel = doc.querySelector('select[name="xnxq01id"]');
    if (sel) {
      const opt = sel.querySelector('option[selected]') ||
          sel.options[sel.selectedIndex] || sel.options[0];
      if (opt) xnxqdm = (opt.getAttribute('value') || opt.textContent || '').trim();
    }
    if (!xnxqdm) throw new Error('找不到 xnxq01id');

    // —— 课程格子 —— 只取 class="kbcontent",忽略悬浮预览用的 kbcontent1
    const rows = [];
    const blocks = doc.querySelectorAll('div.kbcontent');
    blocks.forEach((blk) => {
      // id 形如 "{uuid}-{day}-{slotGroup}"; day 是星期(1..7)
      const id = blk.getAttribute('id') || '';
      const m = id.match(/-(\d+)-(\d+)$/);
      if (!m) return;
      const dayOfWeek = parseInt(m[1], 10);
      if (dayOfWeek < 1 || dayOfWeek > 7) return;

      // 把 kbcontent 内的 <font> 按顺序收集:
      //   [0] 无 title,是课程名
      //   title='教师' => 教师
      //   title='周次(节次)' => 周次 + 节次
      //   title='教室' / '教学楼' => 地点
      const fonts = blk.querySelectorAll(':scope > font');
      // jsxsd 的同一个 td 可能有多门课,但每个课程已经是独立 div.kbcontent。
      // 不过有时候会把多组课程写到同一个 kbcontent 里,用多组 font 叠加。
      // 我们按"遇到下一个课程名 font(无 title)就切段"的方式分组。
      let cur = null;
      const groups = [];
      fonts.forEach((f) => {
        const title = f.getAttribute('title') || '';
        const text = (f.innerText || f.textContent || '').trim();
        if (!text) return;
        if (!title) {
          // 无 title 且长度看起来像课名(含汉字/字母),视为新段开始
          if (/[一-龥A-Za-z]/.test(text) && !/^\d+$/.test(text)) {
            if (cur) groups.push(cur);
            cur = { name: text, teacher: '', location: '', weeks: [], start: 0, end: 0 };
          }
          return;
        }
        if (!cur) return;
        if (title.indexOf('教师') >= 0) {
          cur.teacher = text;
        } else if (title.indexOf('周次') >= 0 || title.indexOf('节次') >= 0) {
          const ws = parseWeeksAndSections(text);
          if (ws) {
            cur.weeks = ws.weeks;
            cur.start = ws.start;
            cur.end = ws.end;
          }
        } else if (title.indexOf('教室') >= 0 || title.indexOf('地点') >= 0) {
          cur.location = cleanLocation(text);
        } else if (title.indexOf('教学楼') >= 0) {
          if (!cur.location) cur.location = cleanLocation(text);
        }
      });
      if (cur) groups.push(cur);

      groups.forEach((g) => {
        if (!g.name || !g.weeks.length || !g.start) return;
        rows.push({
          name: g.name,
          teacher: g.teacher,
          location: g.location,
          dayOfWeek: dayOfWeek,
          startSection: g.start,
          endSection: g.end,
          weeks: g.weeks,
        });
      });
    });

    if (!rows.length) throw new Error('未解析到课程,请在浏览器查看 xskb_list.do 是否正常');

    // —— totalWeeks:取所有周次里的最大值,兜底 20 ——
    let total = 20;
    for (const r of rows) {
      for (const w of r.weeks) if (w > total) total = w;
    }

    // —— startDate:xnxq01id 形如 "2025-2026-2"(-1 秋 / -2 春 / -3 暑),
    //    根据类型挑一个典型开学周一。用户可在"学期设置"再改。
    const startDate = guessStartDate(xnxqdm);

    report({
      ok: true,
      xnxqdm: xnxqdm,
      termName: xnxqdm,
      startDate: startDate,
      totalWeeks: total,
      rows: rows,
    });
  } catch (e) {
    report({ ok: false, error: (e && e.message) ? e.message : String(e) });
  }

  function parseWeeksAndSections(text) {
    // 典型:  "9-17(周)[1-2节]" / "9-18(周)[3-4-5节]" / "1,3-5(单)[6-7节]" / "19(周)[3-4节]"
    const clean = text.replace(/\s+/g, '');
    const wkMatch = clean.match(/^([\d,\-]+)(\([单双周]+\))?/);
    const secMatch = clean.match(/\[([\d\-]+)节?\]/);
    if (!wkMatch || !secMatch) return null;
    const weeks = expandWeeks(wkMatch[1], wkMatch[2] || '');
    const nums = secMatch[1].split('-').map((s) => parseInt(s, 10)).filter((n) => !isNaN(n));
    if (!weeks.length || !nums.length) return null;
    return { weeks: weeks, start: nums[0], end: nums[nums.length - 1] };
  }

  function expandWeeks(expr, parity) {
    const set = new Set();
    expr.split(',').forEach((seg) => {
      const m = seg.match(/^(\d+)(?:-(\d+))?$/);
      if (!m) return;
      const a = parseInt(m[1], 10);
      const b = m[2] ? parseInt(m[2], 10) : a;
      for (let i = a; i <= b; i++) {
        if (parity.indexOf('单') >= 0 && i % 2 === 0) continue;
        if (parity.indexOf('双') >= 0 && i % 2 === 1) continue;
        set.add(i);
      }
    });
    return Array.from(set).sort((x, y) => x - y);
  }

  function cleanLocation(text) {
    // "2号楼C区2号楼C区C123" —— jsxsd 这个字段经常把教学楼短名拼两次后接具体教室。
    // 做法:从左边尽量长地找一个"前缀 P, 使得 t = P + P + rest",然后只保留 "P + rest"。
    let t = text.replace(/【[^】]+】/g, '').trim();
    for (let len = Math.floor(t.length / 2); len >= 2; len--) {
      const pre = t.slice(0, len);
      if (t.slice(len, len * 2) === pre) {
        t = pre + t.slice(len * 2);
        break;
      }
    }
    return t;
  }

  function guessStartDate(xnxqdm) {
    // xnxqdm = "2025-2026-2",split 出起始学年 + 学期号
    const m = xnxqdm.match(/^(\d{4})-(\d{4})-(\d)$/);
    const now = new Date();
    if (!m) return isoDate(mondayOf(now));
    const y1 = parseInt(m[1], 10);
    const y2 = parseInt(m[2], 10);
    const term = parseInt(m[3], 10);
    let anchor;
    if (term === 1) anchor = new Date(y1, 8, 1);         // 9/1
    else if (term === 2) anchor = new Date(y2, 1, 20);   // 2/20
    else anchor = new Date(y2, 5, 20);                   // 6/20 短学期
    return isoDate(mondayOf(anchor));
  }

  function mondayOf(d) {
    const day = d.getDay(); // 0=日
    const delta = day === 0 ? -6 : 1 - day;
    const out = new Date(d);
    out.setDate(d.getDate() + delta);
    return out;
  }

  function isoDate(d) {
    const y = d.getFullYear();
    const m = String(d.getMonth() + 1).padStart(2, '0');
    const dd = String(d.getDate()).padStart(2, '0');
    return y + '-' + m + '-' + dd;
  }
})();
''';
}
