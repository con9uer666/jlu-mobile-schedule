import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/appearance_provider.dart';
import '../state/notification_settings_provider.dart';
import '../data/storage.dart';
import '../state/schedule_providers.dart';
import 'import_page.dart';
import 'semester_setup_page.dart';
import 'day_swap_page.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appearance = ref.watch(appearanceProvider);
    final appearanceCtrl = ref.read(appearanceProvider.notifier);
    final notif = ref.watch(notificationSettingsProvider);
    final notifCtrl = ref.read(notificationSettingsProvider.notifier);
    return CupertinoPageScaffold(
      backgroundColor:
          CupertinoColors.systemGroupedBackground.resolveFrom(context),
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
                header: const Text('学期'),
                children: [
                  CupertinoListTile(
                    title: const Text('当前学期'),
                    additionalInfo: Text(
                      ref.watch(currentSemesterProvider)?.name ?? '未设置',
                    ),
                    trailing: const CupertinoListTileChevron(),
                    onTap: () => _pickSemester(context, ref),
                  ),
                  CupertinoListTile(
                    title: const Text('从教务导入'),
                    trailing: const CupertinoListTileChevron(),
                    onTap: () => Navigator.of(context).push(
                      CupertinoPageRoute(builder: (_) => const ImportPage()),
                    ),
                  ),
                  CupertinoListTile(title: const Text('整天调课'), trailing: const CupertinoListTileChevron(), onTap: () => Navigator.of(context).push(CupertinoPageRoute(builder: (_) => const DaySwapPage()))),
                ],
              ),
              CupertinoListSection.insetGrouped(
                header: const Text('通知'),
                children: [
                  CupertinoListTile(
                    title: const Text('课程提醒'),
                    trailing: CupertinoSwitch(
                      value: notif.coursesEnabled,
                      onChanged: notifCtrl.setCoursesEnabled,
                    ),
                  ),
                  CupertinoListTile(
                    title: const Text('默认提前'),
                    additionalInfo: Text('${notif.defaultLeadMinutes} 分钟'),
                    trailing: const CupertinoListTileChevron(),
                    onTap: () => _pickLead(context, notifCtrl, notif.defaultLeadMinutes),
                  ),
                  CupertinoListTile(
                    title: const Text('每周预报(周日晚)'),
                    trailing: CupertinoSwitch(
                      value: notif.weeklyDigestEnabled,
                      onChanged: notifCtrl.setWeeklyDigestEnabled,
                    ),
                  ),
                ],
              ),
              CupertinoListSection.insetGrouped(
                header: const Text('外观'),
                children: [
                  CupertinoListTile(
                    title: const Text('模式'),
                    trailing: CupertinoSlidingSegmentedControl<AppearanceMode>(
                      groupValue: appearance.mode,
                      children: const {
                        AppearanceMode.system: Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          child: Text('自动'),
                        ),
                        AppearanceMode.light: Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          child: Text('浅'),
                        ),
                        AppearanceMode.dark: Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
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
                        horizontal: 16, vertical: 12),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        for (int i = 0; i < accentColors.length; i++)
                          _AccentChip(
                            color: accentColors[i],
                            selected: i == appearance.accentIndex,
                            onTap: () => appearanceCtrl.setAccent(i),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  '课程表 1.0',
                  style: TextStyle(
                    fontSize: 12,
                    color: CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 100),
            ]),
          ),
        ],
      ),
    );
  }

  Future<void> _pickSemester(BuildContext context, WidgetRef ref) async {
    final semesters = AppStorage.semesters.values.toList();
    if (semesters.isEmpty) {
      await Navigator.of(context).push(CupertinoPageRoute(
        builder: (_) => const SemesterSetupPage(),
      ));
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
              Navigator.of(context).push(CupertinoPageRoute(
                builder: (_) => const SemesterSetupPage(),
              ));
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
    final resolved = CupertinoDynamicColor.maybeResolve(color, context) ?? color;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: resolved,
          border: selected
              ? Border.all(
                  color: CupertinoColors.label.resolveFrom(context),
                  width: 3,
                )
              : null,
        ),
      ),
    );
  }
}

Future<void> _pickLead(
    BuildContext context, NotificationSettingsController ctrl, int current) {
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
