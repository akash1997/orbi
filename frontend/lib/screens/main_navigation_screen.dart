import 'package:flutter/material.dart';
import 'package:flutter_floating_bottom_bar/flutter_floating_bottom_bar.dart';
import 'home/home_screen.dart';
import 'conversations/conversations_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen>
    with SingleTickerProviderStateMixin {
  late int currentPage;
  late TabController tabController;

  @override
  void initState() {
    currentPage = 0;
    tabController = TabController(length: 2, vsync: this);
    tabController.addListener(() {
      setState(() {
        currentPage = tabController.index;
      });
    });
    super.initState();
  }

  @override
  void dispose() {
    tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BottomBar(
        fit: StackFit.expand,
        borderRadius: BorderRadius.circular(24),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        showIcon: true,
        width: MediaQuery.of(context).size.width * 0.6,
        barColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        start: 2,
        end: 0,
        offset: 16,
        barAlignment: Alignment.bottomCenter,
        iconHeight: 28,
        iconWidth: 28,
        reverse: false,
        hideOnScroll: false,
        scrollOpposite: false,
        onBottomBarHidden: () {},
        body: (context, controller) => TabBarView(
          controller: tabController,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            const HomeScreen(),
            const ConversationsScreen(),
          ],
        ),
        child: TabBar(
          controller: tabController,
          indicatorPadding: const EdgeInsets.fromLTRB(6, 0, 6, 0),
          indicator: UnderlineTabIndicator(
            borderSide: BorderSide(
              color: Theme.of(context).colorScheme.primary,
              width: 3,
            ),
            insets: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            borderRadius: BorderRadius.circular(8),
          ),
          tabs: [
            Tab(
              icon: Icon(
                Icons.person,
                color: currentPage == 0
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
              child: Text(
                'Speakers',
                style: TextStyle(
                  color: currentPage == 0
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  fontSize: 12,
                  fontWeight: currentPage == 0 ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
            Tab(
              icon: Icon(
                Icons.chat_bubble_outline,
                color: currentPage == 1
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
              child: Text(
                'Conversations',
                style: TextStyle(
                  color: currentPage == 1
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  fontSize: 12,
                  fontWeight: currentPage == 1 ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
