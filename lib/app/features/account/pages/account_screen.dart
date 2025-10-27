import 'package:flutter/material.dart';
import 'package:sympli_ai_health/app/features/account/pages/profile_screen.dart';
import 'package:sympli_ai_health/app/features/account/pages/settings_screen.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key, this.initialTabIndex = 0});
  final int initialTabIndex;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: initialTabIndex.clamp(0, 1),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Account'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.person), text: 'Profile'),
              Tab(icon: Icon(Icons.settings), text: 'Settings'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            ProfileScreen(),
            SettingsScreen(),
          ],
        ),
      ),
    );
  }
}

