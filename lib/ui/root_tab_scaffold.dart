import 'package:flutter/cupertino.dart';

import '../navigation/nav_keys.dart';
import '../navigation/tab_router.dart';
import 'agenda_page.dart';
import 'home_page.dart';
import 'widgets/glass_pill.dart';

class RootTabScaffold extends StatefulWidget {
  const RootTabScaffold({super.key});

  @override
  State<RootTabScaffold> createState() => _RootTabScaffoldState();
}

class _RootTabScaffoldState extends State<RootTabScaffold> {
  int _index = TabRouter.currentIndex.value;

  @override
  void initState() {
    super.initState();
    TabRouter.currentIndex.addListener(_onExternalSwitch);
  }

  void _onExternalSwitch() {
    if (_index != TabRouter.currentIndex.value) {
      setState(() => _index = TabRouter.currentIndex.value);
    }
  }

  @override
  void dispose() {
    TabRouter.currentIndex.removeListener(_onExternalSwitch);
    super.dispose();
  }

  void _select(int i) {
    if (i == _index) return;
    TabRouter.currentIndex.value = i;
    setState(() => _index = i);
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor:
          CupertinoColors.systemBackground.resolveFrom(context),
      child: Stack(
        children: [
          _TabHost(
            index: _index,
            tabs: [
              CupertinoTabView(
                navigatorKey: courseTabNavKey,
                builder: (_) => const HomePage(),
              ),
              CupertinoTabView(
                navigatorKey: agendaTabNavKey,
                builder: (_) => const AgendaPage(),
              ),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              minimum: const EdgeInsets.only(bottom: 12),
              child: Center(
                child: _FloatingTabBar(
                  index: _index,
                  onTap: _select,
                  items: const [
                    _TabItem(icon: CupertinoIcons.calendar, label: '课程表'),
                    _TabItem(
                      icon: CupertinoIcons.list_bullet_below_rectangle,
                      label: '日程',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 用 Offstage + IndexedStack 风格保留每个 tab 的 Navigator 状态。
/// 直接用 IndexedStack 在 CupertinoTabView 上不能复用,因为 IndexedStack
/// 内部要求 children 是同一类型的 Stateful。这里用手动 Offstage 切换。
class _TabHost extends StatelessWidget {
  const _TabHost({required this.index, required this.tabs});

  final int index;
  final List<Widget> tabs;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        for (int i = 0; i < tabs.length; i++)
          Offstage(
            offstage: i != index,
            child: TickerMode(
              enabled: i == index,
              child: tabs[i],
            ),
          ),
      ],
    );
  }
}

class _TabItem {
  const _TabItem({required this.icon, required this.label});
  final IconData icon;
  final String label;
}

class _FloatingTabBar extends StatelessWidget {
  const _FloatingTabBar({
    required this.index,
    required this.onTap,
    required this.items,
  });

  final int index;
  final ValueChanged<int> onTap;
  final List<_TabItem> items;

  @override
  Widget build(BuildContext context) {
    final accent = CupertinoTheme.of(context).primaryColor;
    final inactive = CupertinoColors.secondaryLabel.resolveFrom(context);

    return GlassPill(
      radius: 32,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (int i = 0; i < items.length; i++)
              _PillTab(
                item: items[i],
                selected: i == index,
                accent: accent,
                inactive: inactive,
                onTap: () => onTap(i),
              ),
          ],
        ),
      ),
    );
  }
}

class _PillTab extends StatelessWidget {
  const _PillTab({
    required this.item,
    required this.selected,
    required this.accent,
    required this.inactive,
    required this.onTap,
  });

  final _TabItem item;
  final bool selected;
  final Color accent;
  final Color inactive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? accent : inactive;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          color: selected
              ? accent.withValues(alpha: 0.14)
              : const Color(0x00000000),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(item.icon, size: 20, color: fg),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              child: selected
                  ? Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Text(
                        item.label,
                        style: TextStyle(
                          color: fg,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
