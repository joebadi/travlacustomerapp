import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:travla_customer_app/app/theme/app_colors.dart';
import 'package:travla_customer_app/features/forum/presentation/forum_screen.dart';
import 'package:travla_customer_app/features/news/presentation/news_screen.dart';
import 'package:travla_customer_app/features/stolen/presentation/stolen_screen.dart';
import 'package:travla_customer_app/shared/widgets/travla_app_bar.dart';

/// "Car Talk" — the bottom-nav tab that replaced "News". Brings the
/// newsroom, the community forum, and the stolen-vehicle registry together
/// as a professional 3-tab page (mirrors the web's single unified Car Talk
/// nav entry), with a tab-aware FAB for each tab's primary action.
class CarTalkScreen extends StatefulWidget {
  const CarTalkScreen({super.key});

  @override
  State<CarTalkScreen> createState() => _CarTalkScreenState();
}

class _CarTalkScreenState extends State<CarTalkScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _stolenKey = GlobalKey<StolenFeedTabState>();
  int _tabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this)
      ..addListener(() {
        if (_tabController.index != _tabIndex) {
          setState(() => _tabIndex = _tabController.index);
        }
      });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: TravlaAppBar(
        showMenuButton: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.forest700,
          unselectedLabelColor: AppColors.muted,
          indicatorColor: AppColors.forest700,
          indicatorWeight: 3,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
          tabs: const [
            Tab(text: 'Blogs'),
            Tab(text: 'Forum'),
            Tab(text: 'Report'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          const NewsFeedTab(),
          const ForumFeedTab(),
          StolenFeedTab(key: _stolenKey),
        ],
      ),
      floatingActionButton: _fab(),
    );
  }

  Widget? _fab() {
    switch (_tabIndex) {
      case 1:
        return FloatingActionButton.extended(
          backgroundColor: AppColors.orange,
          onPressed: () => context.push('/more/forum/new'),
          icon: const Icon(Icons.edit_outlined),
          label: const Text('New thread'),
        );
      case 2:
        return FloatingActionButton.extended(
          backgroundColor: AppColors.danger,
          onPressed: () => _stolenKey.currentState?.reportStolen(),
          icon: const Icon(Icons.report_gmailerrorred_rounded),
          label: const Text('Report stolen'),
        );
      default:
        return null;
    }
  }
}
