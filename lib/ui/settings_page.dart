import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/appearance_provider.dart';
import '../state/notification_settings_provider.dart';
import '../data/storage.dart';
import '../state/schedule_providers.dart';
import 'import_page.dart';
import 'semester_setup_page.dart';
import 'day_swap_page.dart';
import 'history_page.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    final appearance = ref.watch(appearanceProvider);
    final appearanceCtrl = ref.read(appearanceProvider.notifier);
    final notif = ref.watch(notificationSettingsProvider);
    final notifCtrl = ref.read(notificationSettingsProvider.notifier);
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(
        context,
      ),
      child: CustomScrollView(
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: const Text('设置'),
            backgroundColor: CupertinoColors.systemBackground
                .resolveFrom(context)
                .withValues(alpha: 0.7),
            border: null,
          ),
          SliverList(
            delegate: SliverChildListDelegate([
              CupertinoListSection.insetGrouped(
                header: const Text('课程与学期'),
                footer: const Text('管理课程来源、当前学期和临时调课。'),
                children: [
                  CupertinoListTile(
                    leading: const _SettingsIcon(
                      icon: CupertinoIcons.calendar,
                      color: CupertinoColors.systemIndigo,
                    ),
                    title: const Text('当前学期'),
                    additionalInfo: Text(
                      ref.watch(currentSemesterProvider)?.name ?? '未设置',
                    ),
                    trailing: const CupertinoListTileChevron(),
                    onTap: () => _pickSemester(context),
                  ),
                  CupertinoListTile(
                    leading: const _SettingsIcon(
                      icon: CupertinoIcons.cloud_download_fill,
                      color: CupertinoColors.activeBlue,
                    ),
                    title: const Text('从教务导入'),
                    subtitle: const Text('更新课程表数据'),
                    trailing: const CupertinoListTileChevron(),
                    onTap: () => Navigator.of(context).push(
                      CupertinoPageRoute(builder: (_) => const ImportPage()),
                    ),
                  ),
                  CupertinoListTile(
                    leading: const _SettingsIcon(
                      icon: CupertinoIcons.arrow_2_circlepath,
                      color: CupertinoColors.systemOrange,
                    ),
                    title: const Text('整天调课'),
                    subtitle: const Text('设置补课、调休和日期替换'),
                    trailing: const CupertinoListTileChevron(),
                    onTap: () => Navigator.of(context).push(
                      CupertinoPageRoute(builder: (_) => const DaySwapPage()),
                    ),
                  ),
                ],
              ),
              CupertinoListSection.insetGrouped(
                header: const Text('提醒'),
                footer: const Text('作业、考试和待办可在各自的编辑页面单独调整提醒。'),
                children: [
                  CupertinoListTile(
                    leading: const _SettingsIcon(
                      icon: CupertinoIcons.bell_fill,
                      color: CupertinoColors.systemRed,
                    ),
                    title: const Text('课程提醒'),
                    subtitle: const Text('在课程开始前收到通知'),
                    trailing: CupertinoSwitch(
                      value: notif.coursesEnabled,
                      onChanged: notifCtrl.setCoursesEnabled,
                    ),
                  ),
                  CupertinoListTile(
                    leading: const _SettingsIcon(
                      icon: CupertinoIcons.timer_fill,
                      color: CupertinoColors.systemOrange,
                    ),
                    title: const Text('默认提前'),
                    additionalInfo: Text('${notif.defaultLeadMinutes} 分钟'),
                    trailing: const CupertinoListTileChevron(),
                    onTap: () =>
                        _pickLead(context, notifCtrl, notif.defaultLeadMinutes),
                  ),
                  CupertinoListTile(
                    leading: const _SettingsIcon(
                      icon: CupertinoIcons.news_solid,
                      color: CupertinoColors.systemPurple,
                    ),
                    title: const Text('每周预报(周日晚)'),
                    subtitle: const Text('预览下周课程安排'),
                    trailing: CupertinoSwitch(
                      value: notif.weeklyDigestEnabled,
                      onChanged: notifCtrl.setWeeklyDigestEnabled,
                    ),
                  ),
                ],
              ),
              CupertinoListSection.insetGrouped(
                header: const Text('任务与数据'),
                children: [
                  CupertinoListTile(
                    leading: const _SettingsIcon(
                      icon: CupertinoIcons.clock_fill,
                      color: CupertinoColors.systemTeal,
                    ),
                    title: const Text('模糊日期默认截止时间'),
                    subtitle: const Text('用于没有写具体时间的内容'),
                    additionalInfo: Text(
                      '${AppStorage.settings.get('study_default_due_hour', defaultValue: 22).toString().padLeft(2, '0')}:00',
                    ),
                    trailing: const CupertinoListTileChevron(),
                    onTap: () => _pickDefaultDueHour(context),
                  ),
                  CupertinoListTile(
                    leading: const _SettingsIcon(
                      icon: CupertinoIcons.archivebox_fill,
                      color: CupertinoColors.systemBrown,
                    ),
                    title: const Text('历史记录'),
                    subtitle: const Text('查看已完成作业、考试和待办'),
                    trailing: const CupertinoListTileChevron(),
                    onTap: () => Navigator.of(context).push(
                      CupertinoPageRoute(builder: (_) => const HistoryPage()),
                    ),
                  ),
                ],
              ),
              CupertinoListSection.insetGrouped(
                header: const Text('外观'),
                footer: const Text('主题颜色用于选中状态、提醒和界面强调。'),
                children: [
                  CupertinoListTile(
                    leading: const _SettingsIcon(
                      icon: CupertinoIcons.circle_lefthalf_fill,
                      color: CupertinoColors.systemGrey,
                    ),
                    title: const Text('显示模式'),
                    trailing: CupertinoSlidingSegmentedControl<AppearanceMode>(
                      groupValue: appearance.mode,
                      children: const {
                        AppearanceMode.system: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          child: Text('自动'),
                        ),
                        AppearanceMode.light: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          child: Text('浅'),
                        ),
                        AppearanceMode.dark: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          child: Text('深'),
                        ),
                      },
                      onValueChanged: (v) {
                        if (v != null) appearanceCtrl.setMode(v);
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        const Text(
                          '主题颜色',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        const Spacer(),
                        Wrap(
                          spacing: 7,
                          children: [
                            for (int i = 0; i < accentColors.length; i++)
                              _AccentChip(
                                color: accentColors[i],
                                selected: i == appearance.accentIndex,
                                onTap: () => appearanceCtrl.setAccent(i),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              CupertinoListSection.insetGrouped(
                header: const Text('关于'),
                children: const [
                  CupertinoListTile(
                    leading: _SettingsIcon(
                      icon: CupertinoIcons.info_circle_fill,
                      color: CupertinoColors.systemBlue,
                    ),
                    title: Text('课程表'),
                    subtitle: Text('课程、作业、考试与个人待办'),
                    additionalInfo: Text('1.0.0 (2)'),
                  ),
                ],
              ),
              const SizedBox(height: 100),
            ]),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDefaultDueHour(BuildContext context) async {
    final current =
        AppStorage.settings.get('study_default_due_hour', defaultValue: 22)
            as int;
    var selected = current;
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => Container(
        height: 260,
        color: CupertinoColors.systemBackground.resolveFrom(ctx),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              Row(
                children: [
                  CupertinoButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('取消'),
                  ),
                  const Spacer(),
                  CupertinoButton(
                    onPressed: () async {
                      await AppStorage.settings.put(
                        'study_default_due_hour',
                        selected,
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (mounted) setState(() {});
                    },
                    child: const Text('完成'),
                  ),
                ],
              ),
              Expanded(
                child: CupertinoPicker(
                  itemExtent: 36,
                  scrollController: FixedExtentScrollController(
                    initialItem: current,
                  ),
                  onSelectedItemChanged: (value) => selected = value,
                  children: [
                    for (var hour = 0; hour < 24; hour++)
                      Center(
                        child: Text('${hour.toString().padLeft(2, '0')}:00'),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickSemester(BuildContext context) async {
    final semesters = AppStorage.semesters.values.toList();
    if (semesters.isEmpty) {
      await Navigator.of(
        context,
      ).push(CupertinoPageRoute(builder: (_) => const SemesterSetupPage()));
      return;
    }
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('选择当前学期'),
        actions: [
          for (final semester in semesters)
            CupertinoActionSheetAction(
              onPressed: () {
                ref.read(currentSemesterProvider.notifier).setCurrent(semester);
                Navigator.of(ctx).pop();
              },
              child: Text(semester.name),
            ),
          CupertinoActionSheetAction(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).push(
                CupertinoPageRoute(builder: (_) => const SemesterSetupPage()),
              );
            },
            child: const Text('新建/编辑学期'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('取消'),
        ),
      ),
    );
  }
}

class _AccentChip extends StatelessWidget {
  const _AccentChip({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final resolved =
        CupertinoDynamicColor.maybeResolve(color, context) ?? color;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 27,
        height: 27,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: resolved,
          border: selected
              ? Border.all(
                  color: CupertinoColors.label.resolveFrom(context),
                  width: 2.5,
                )
              : null,
        ),
      ),
    );
  }
}

class _SettingsIcon extends StatelessWidget {
  const _SettingsIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final resolved =
        CupertinoDynamicColor.maybeResolve(color, context) ?? color;
    return Container(
      width: 31,
      height: 31,
      decoration: BoxDecoration(
        color: resolved,
        borderRadius: BorderRadius.circular(7),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: 17, color: CupertinoColors.white),
    );
  }
}

Future<void> _pickLead(
  BuildContext context,
  NotificationSettingsController ctrl,
  int current,
) {
  const options = [5, 10, 15, 30, 60];
  return showCupertinoModalPopup<void>(
    context: context,
    builder: (ctx) {
      int picked = current;
      return Container(
        height: 240,
        color: CupertinoColors.systemBackground.resolveFrom(ctx),
        child: SafeArea(
          top: false,
          child: Column(
            children: [
              SizedBox(
                height: 44,
                child: Row(
                  children: [
                    CupertinoButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('取消'),
                    ),
                    const Spacer(),
                    CupertinoButton(
                      onPressed: () {
                        ctrl.setDefaultLead(picked);
                        Navigator.of(ctx).pop();
                      },
                      child: const Text('完成'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CupertinoPicker(
                  itemExtent: 36,
                  scrollController: FixedExtentScrollController(
                    initialItem: options.contains(current)
                        ? options.indexOf(current)
                        : 1,
                  ),
                  onSelectedItemChanged: (i) => picked = options[i],
                  children: [
                    for (final m in options) Center(child: Text('$m 分钟')),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
