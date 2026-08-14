import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:travla_customer_app/app/theme/app_colors.dart';
import 'package:travla_customer_app/features/forum/presentation/forum_screen.dart';
import 'package:travla_customer_app/features/news/presentation/news_screen.dart';
import 'package:travla_customer_app/features/stolen/presentation/reports_tab.dart';
import 'package:travla_customer_app/shared/widgets/travla_app_bar.dart';

/// Mobile Car Talk workspace.
///
/// This intentionally does not use TabBarView. Only the selected section is
/// mounted, which prevents offstage API work and nested page-view layout from
/// affecting the Reports registry on compact devices.
class CarTalkScreen extends StatefulWidget {
  const CarTalkScreen({super.key, this.initialIndex = 0})
    : assert(initialIndex >= 0 && initialIndex < 3);

  final int initialIndex;

  @override
  State<CarTalkScreen> createState() => _CarTalkScreenState();
}

class _CarTalkScreenState extends State<CarTalkScreen> {
  late int _sectionIndex;

  @override
  void initState() {
    super.initState();
    _sectionIndex = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: const TravlaAppBar(),
      body: Column(
        children: [
          _CarTalkNavigation(
            selectedIndex: _sectionIndex,
            onSelected: (index) => setState(() => _sectionIndex = index),
          ),
          Expanded(child: _selectedSection()),
        ],
      ),
      floatingActionButton: _sectionIndex == 1
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.orange,
              onPressed: () => context.push('/more/forum/new'),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('New thread'),
            )
          : null,
    );
  }

  Widget _selectedSection() {
    return switch (_sectionIndex) {
      1 => const ForumFeedTab(key: ValueKey('car-talk-forum')),
      2 => const ReportsFeedTab(key: ValueKey('car-talk-reports')),
      _ => const NewsFeedTab(key: ValueKey('car-talk-blogs')),
    };
  }
}

class _CarTalkNavigation extends StatelessWidget {
  const _CarTalkNavigation({
    required this.selectedIndex,
    required this.onSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;

  static const _items = [
    (label: 'Blogs', icon: Icons.newspaper_outlined),
    (label: 'Forum', icon: Icons.forum_outlined),
    (label: 'Reports', icon: Icons.shield_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 4, 14, 10),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFE7EFEB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: List.generate(_items.length, (index) {
          final item = _items[index];
          final selected = selectedIndex == index;
          return Expanded(
            child: Semantics(
              button: true,
              selected: selected,
              label: item.label,
              child: Material(
                color: selected ? AppColors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                elevation: selected ? 1 : 0,
                child: InkWell(
                  onTap: () => onSelected(index),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          item.icon,
                          size: 17,
                          color: selected
                              ? AppColors.forest700
                              : AppColors.muted,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            item.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: selected
                                  ? AppColors.forest900
                                  : AppColors.muted,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
