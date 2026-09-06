import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/course.dart';
import '../data/providers/registry.dart';
import '../data/raw_entry.dart';
import '../data/school_provider.dart';
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
  static const _prefKey = 'import.lastProviderId';

  bool _busy = false;
  String? _error;
  String _status = '';
  late SchoolProvider _provider;

  @override
  void initState() {
    super.initState();
    final savedId = AppStorage.settings.get(_prefKey) as String?;
    _provider = (savedId == null ? null : findProvider(savedId)) ??
        defaultProvider;
  }

  Future<void> _pickSchool() async {
    final picked = await showCupertinoModalPopup<SchoolProvider>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('选择学校教务'),
        actions: [
          for (final p in schoolProviders)
            CupertinoActionSheetAction(
              onPressed: () => Navigator.of(ctx).pop(p),
              child: Text(p.displayName),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('取消'),
        ),
      ),
    );
    if (picked != null && picked.id != _provider.id) {
      await AppStorage.settings.put(_prefKey, picked.id);
      if (mounted) setState(() => _provider = picked);
    }
  }

  Future<void> _start() async {
    setState(() {
      _busy = true;
      _error = null;
      _status = '打开登录页...';
    });

    final bundle = await Navigator.of(context).push<Map<String, dynamic>>(
      CupertinoPageRoute(
        builder: (_) => SchoolLoginPage(provider: _provider),
      ),
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

    final entries = _provider.parseRows(rows);

    final semester = Semester(
      id: xnxqdm,
      name: termName.isEmpty ? xnxqdm : termName,
      startDate: startDate,
      totalWeeks: totalWeeks,
      sectionCount: _maxEndSection(entries),
    );

    // 先在内存构建所有新课程对象，减少删旧→插新之间的空窗期
    var i = 0;
    final newCourses = <MapEntry<String, Course>>[];
    for (final e in entries) {
      final id = '$xnxqdm-$i';
      newCourses.add(MapEntry(id, Course(
        id: id,
        name: e.name,
        teacher: e.teacher,
        location: e.location,
        dayOfWeek: e.dayOfWeek,
        startSection: e.startSection,
        endSection: e.endSection,
        weeks: e.weeks,
        colorIndex: CourseColors.stableIndex(e.name),
      )));
      i++;
    }

    for (final old in AppStorage.courses.values
        .where((c) => c.id.startsWith('$xnxqdm-'))
        .toList()) {
      await old.delete();
    }
    for (final entry in newCourses) {
      await AppStorage.courses.put(entry.key, entry.value);
    }

    await AppStorage.semesters.put(semester.id, semester);
    await ref.read(currentSemesterProvider.notifier).setCurrent(semester);
  }

  int _maxEndSection(List<CourseRawEntry> entries) {
    var m = _provider.minSectionCount;
    for (final e in entries) {
      if (e.endSection > m) m = e.endSection;
    }
    return m;
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor:
          CupertinoColors.systemGroupedBackground.resolveFrom(context),
      child: CustomScrollView(
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: const Text('从教务导入'),
            backgroundColor: CupertinoColors.systemBackground
                .resolveFrom(context)
                .withValues(alpha: 0.7),
            border: null,
          ),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
            CupertinoFormSection.insetGrouped(
              header: const Text('学校'),
              margin: EdgeInsets.zero,
              children: [
                CupertinoFormRow(
                  prefix: const Text('教务系统'),
                  child: CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _busy ? null : _pickSchool,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_provider.displayName),
                        const SizedBox(width: 4),
                        const Icon(CupertinoIcons.chevron_right, size: 14),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
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
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
