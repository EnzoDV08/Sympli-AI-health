import 'dart:ui';
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
        extendBodyBehindAppBar: true,
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFFE8FDFB),
                    Color(0xFFFDFEFF),
                    Color(0xFFE3F7FF),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),

            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 35, sigmaY: 35),
              child: Container(color: Colors.white.withOpacity(0.15)),
            ),

            SafeArea(
              child: Column(
                children: [
                  Container(
                    margin:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0.45),
                          Colors.white.withOpacity(0.25),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.6),
                        width: 1.3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF37B7A5).withOpacity(0.15),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Account Settings ⚙️",
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          "Manage your profile, health info and reminders.",
                          style:
                              TextStyle(fontSize: 14, color: Colors.black54),
                        ),
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: Colors.white.withOpacity(0.35),
                          ),
                          child: TabBar(
                            indicatorSize: TabBarIndicatorSize.tab,
                            indicator: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF37B7A5), Color(0xFF1CB5E0)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF37B7A5)
                                      .withOpacity(0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            indicatorPadding: const EdgeInsets.symmetric(
                                horizontal: 30, vertical: 6),
                            labelPadding:
                                const EdgeInsets.symmetric(horizontal: 24),
                            labelColor: Colors.white,
                            unselectedLabelColor: Colors.black87,
                            labelStyle: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                            unselectedLabelStyle: const TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                            tabs: const [
                              Tab(
                                iconMargin: EdgeInsets.only(bottom: 4),
                                icon: Icon(Icons.person, size: 22),
                                text: 'Profile',
                              ),
                              Tab(
                                iconMargin: EdgeInsets.only(bottom: 4),
                                icon: Icon(Icons.settings, size: 22),
                                text: 'Settings',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  Expanded(
                    child: TabBarView(
                      children: [
                        const ProfileScreen(),
                        const SettingsScreen(), 
                      ],
                    ),
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
