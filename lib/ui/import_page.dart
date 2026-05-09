import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/course.dart';
import '../data/raw_entry.dart';
import '../data/semester.dart';
import '../data/storage.dart';
import '../state/schedule_providers.dart';
import 'course_colors.dart';
import 'login_webview_page.dart';

class ImportPage extends ConsumerStatefulWidget {
  const ImportPage({super.key});

  @override
  ConsumerState<ImportPage> createState() => _ImportPageState();
}

class _ImportPageState extends ConsumerState<ImportPage> {
  bool _busy = false;
  String? _error;
  String _status = '';

  Future<void> _start() async {
    setState(() {
      _busy = true;
      _error = null;
      _status = '打开登录页...';
    });

    final bundle = await Navigator.of(context).push<Map<String, dynamic>>(
      CupertinoPageRoute(builder: (_) => const JlujwappLoginPage()),
    );
    if (bundle == null) {
      if (mounted) setState(() => _busy = false);
      return;
    }

    try {
      setState(() => _status = '解析课表...');
      await _persistBundle(bundle);

      if (!mounted) return;
      final entries = (bundle['rows'] as List).length;
      await showCupertinoDialog(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('导入完成'),
          content: Text(
            '学期:${bundle['termName']}\n共解析 $entries 条排课记录',
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('好'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _status = '';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _persistBundle(Map<String, dynamic> bundle) async {
    final xnxqdm = bundle['xnxqdm'] as String;
    final termName = (bundle['termName'] as String?) ?? '';
    final startRaw = (bundle['startDate'] as String).split(' ').first;
    final startDate = DateTime.parse(startRaw);
    final zzc = bundle['totalWeeks'];
    final totalWeeks = zzc is int ? zzc : int.parse('$zzc');
    final rows = (bundle['rows'] as List).cast<Map>();

    final entries = <CourseRawEntry>[];
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
      entries.add(CourseRawEntry(
        name: name,
        teacher: row['SKJS'] as String? ?? '',
        location: row['JASMC'] as String? ?? '',
        dayOfWeek: dayOfWeek,
        startSection: startSection,
        endSection: endSection,
        weeks: weeks,
      ));
    }

    final semester = Semester(
      id: xnxqdm,
      name: termName.isEmpty ? xnxqdm : termName,
      startDate: startDate,
      totalWeeks: totalWeeks,
      sectionCount: _maxEndSection(entries),
    );
    await AppStorage.semesters.put(semester.id, semester);

    for (final old in AppStorage.courses.values
        .where((c) => c.id.startsWith('$xnxqdm-'))
        .toList()) {
      await old.delete();
    }

    var i = 0;
    for (final e in entries) {
      final id = '$xnxqdm-$i';
      final course = Course(
        id: id,
        name: e.name,
        teacher: e.teacher,
        location: e.location,
        dayOfWeek: e.dayOfWeek,
        startSection: e.startSection,
        endSection: e.endSection,
        weeks: e.weeks,
        colorIndex: CourseColors.stableIndex(e.name),
      );
      await AppStorage.courses.put(id, course);
      i++;
    }

    await ref.read(currentSemesterProvider.notifier).setCurrent(semester);
  }

  int _maxEndSection(List<CourseRawEntry> entries) {
    var m = 12;
    for (final e in entries) {
      if (e.endSection > m) m = e.endSection;
    }
    return m;
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('从教务导入')),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              '吉林大学 iedu 教务系统',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              '点击下方按钮会打开学校统一身份认证登录页,登录成功后会自动返回并抓取本学期课表。账号密码不经过本 App。',
              style: TextStyle(
                fontSize: 13,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
            const SizedBox(height: 24),
            CupertinoButton.filled(
              onPressed: _busy ? null : _start,
              child: _busy
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CupertinoActivityIndicator(
                          color: CupertinoColors.white,
                        ),
                        const SizedBox(width: 8),
                        Text(_status, style: const TextStyle(fontSize: 14)),
                      ],
                    )
                  : const Text('开始导入'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: CupertinoColors.systemRed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(
                    color: CupertinoColors.systemRed,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
