import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/study_item.dart';
import '../state/study_providers.dart';

class HistoryPage extends ConsumerStatefulWidget {
  const HistoryPage({super.key});
  @override
  ConsumerState<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends ConsumerState<HistoryPage> {
  int filter = 0;
  @override
  Widget build(BuildContext context) {
    final all =
        ref.watch(studyItemsProvider).asData?.value ?? const <StudyItem>[];
    final now = DateTime.now();
    final items = all
        .where(
          (i) =>
              (filter == 0 || i.kind.index + 1 == filter) &&
              (i.isCompleted ||
                  (i.kind == StudyItemKind.exam &&
                      (i.endAt ?? i.startAt).isBefore(now))),
        )
        .toList()
        .reversed
        .toList();
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(middle: Text('历史记录')),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: CupertinoSlidingSegmentedControl<int>(
                groupValue: filter,
                children: const {
                  0: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('全部'),
                  ),
                  1: Text('作业'),
                  2: Text('考试'),
                  3: Text('待办'),
                },
                onValueChanged: (v) {
                  if (v != null) setState(() => filter = v);
                },
              ),
            ),
            Expanded(
              child: items.isEmpty
                  ? const Center(child: Text('暂无历史记录'))
                  : ListView(
                      children: [
                        CupertinoListSection.insetGrouped(
                          children: [
                            for (final item in items)
                              CupertinoListTile(
                                title: Text(item.title),
                                subtitle: Text(
                                  item.kind == StudyItemKind.exam
                                      ? '考试已结束'
                                      : '已完成',
                                ),
                                additionalInfo: Text(
                                  DateFormat('yyyy/M/d').format(
                                    item.completedAt ??
                                        item.endAt ??
                                        item.startAt,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
