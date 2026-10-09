import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/study_item.dart';
import '../state/study_providers.dart';
import 'quick_add_page.dart';
import 'study_item_editor_page.dart';

class StudyListPage extends ConsumerWidget {
  const StudyListPage({super.key, required this.kind});
  final StudyItemKind kind;

  String get title => switch (kind) {
    StudyItemKind.assignment => '作业',
    StudyItemKind.exam => '考试',
    StudyItemKind.personal => '个人待办',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(studyItemsProvider);
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(
        context,
      ),
      child: CustomScrollView(
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: Text(title),
            trailing: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () => showStudyAddMenu(context, kind: kind),
              child: const Icon(CupertinoIcons.add),
            ),
          ),
          items.when(
            loading: () => const SliverFillRemaining(
              child: Center(child: CupertinoActivityIndicator()),
            ),
            error: (e, _) =>
                SliverFillRemaining(child: Center(child: Text('$e'))),
            data: (all) {
              final now = DateTime.now();
              final active = all
                  .where(
                    (i) =>
                        i.kind == kind &&
                        !i.isCompleted &&
                        !(kind == StudyItemKind.exam &&
                            (i.endAt ?? i.startAt).isBefore(now)),
                  )
                  .toList();
              final overdue = active
                  .where(
                    (i) =>
                        i.startAt.isBefore(now) && kind != StudyItemKind.exam,
                  )
                  .toList();
              final upcoming = active
                  .where((i) => !overdue.contains(i))
                  .toList();
              if (active.isEmpty)
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyStudy(title: title),
                );
              return SliverPadding(
                padding: const EdgeInsets.only(bottom: 100),
                sliver: SliverList.list(
                  children: [
                    if (overdue.isNotEmpty)
                      _StudySection(
                        title: '逾期',
                        items: overdue,
                        isOverdue: true,
                      ),
                    if (upcoming.isNotEmpty)
                      _StudySection(title: '即将到来', items: upcoming),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _StudySection extends ConsumerWidget {
  const _StudySection({
    required this.title,
    required this.items,
    this.isOverdue = false,
  });
  final String title;
  final List<StudyItem> items;
  final bool isOverdue;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      CupertinoListSection.insetGrouped(
        header: Text(title),
        children: [
          for (final item in items)
            CupertinoListTile(
              leading: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: item.kind == StudyItemKind.exam
                    ? null
                    : () => ref
                          .read(studyItemsControllerProvider)
                          .setCompleted(item, true),
                child: Icon(
                  item.kind == StudyItemKind.exam
                      ? CupertinoIcons.doc_text
                      : CupertinoIcons.circle,
                  size: 21,
                ),
              ),
              title: Text(
                item.title,
                style: TextStyle(
                  color: isOverdue ? CupertinoColors.systemRed : null,
                ),
              ),
              subtitle: item.submissionMethod != null
                  ? Text(item.submissionMethod!)
                  : (item.location != null ? Text(item.location!) : null),
              additionalInfo: Text(
                DateFormat(
                  item.allDay ? 'M/d' : 'M/d HH:mm',
                ).format(item.startAt),
              ),
              trailing: const CupertinoListTileChevron(),
              onTap: () => Navigator.of(context).push(
                CupertinoPageRoute(
                  builder: (_) =>
                      StudyItemEditorPage(kind: item.kind, existing: item),
                ),
              ),
            ),
        ],
      );
}

class _EmptyStudy extends StatelessWidget {
  const _EmptyStudy({required this.title});
  final String title;
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          CupertinoIcons.check_mark_circled,
          size: 56,
          color: CupertinoColors.systemGrey3.resolveFrom(context),
        ),
        const SizedBox(height: 12),
        Text(
          '暂无$title',
          style: TextStyle(
            color: CupertinoColors.secondaryLabel.resolveFrom(context),
          ),
        ),
      ],
    ),
  );
}
