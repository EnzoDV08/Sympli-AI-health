import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:sympli_ai_health/app/core/widgets/sympli_navbar.dart';
import 'package:sympli_ai_health/app/features/splash/splash_screen.dart';
import 'package:sympli_ai_health/app/features/onboarding/onboarding_screen.dart';
import 'package:sympli_ai_health/app/features/auth/screens/auth_screen.dart';
import 'package:sympli_ai_health/app/features/onboarding/health_intro_flow.dart';
import 'package:sympli_ai_health/app/features/home/home_screen.dart';
import 'package:sympli_ai_health/app/features/account/pages/account_screen.dart';
import 'package:sympli_ai_health/app/features/account/pages/profile_screen.dart';
import 'package:sympli_ai_health/app/features/account/pages/chat_history_screen.dart';
import 'package:sympli_ai_health/app/features/account/pages/settings_screen.dart';
import 'package:sympli_ai_health/app/features/chat_ai/pages/chat_ai_screen.dart';
import 'package:sympli_ai_health/app/features/logs/pages/logs_screen.dart';


final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    debugLogDiagnostics: true,
    routes: [

      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/auth',
        builder: (context, state) => const AuthScreen(),
      ),
      GoRoute(
        path: '/intro',
        builder: (context, state) => const HealthIntroFlow(),
      ),

      ShellRoute(
        builder: (context, state, child) {
          return Scaffold(
            backgroundColor: const Color(0xFFF6F8FB),
            body: Stack(
              children: [
                child,
                Align(
                  alignment: Alignment.bottomCenter,
                  child: SympliNavBar(
                    currentIndex: _getIndexForPath(state.uri.toString()),
                    onTap: (i) {
                      switch (i) {
                        case 0:
                          context.go('/home');
                          break;
                        case 1:
                          context.go('/logs');
                          break;
                        case 2:
                          context.go('/account');
                          break;
                      }
                    },
                    onBellTap: () {
                    },
                  ),
                ),
              ],
            ),
          );
        },

        routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) => const HomeScreen(),
          ),
          GoRoute(
            path: '/logs',
            builder: (context, state) => const LogsScreen(),
          ),

          GoRoute(
            path: '/account',
            builder: (context, state) => const AccountScreen(),
            routes: [
              GoRoute(
                path: 'profile',
                builder: (context, state) => const ProfileScreen(),
              ),
              GoRoute(
                path: 'chats',
                builder: (context, state) => const ChatHistoryScreen(),
              ),
              GoRoute(
                path: 'settings',
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),

      GoRoute(
        path: '/chat-ai',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const ChatAIScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(0.0, 1.0);
            const end = Offset.zero;
            const curve = Curves.easeInOutCubic;

            final tween =
                Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
            final fadeTween =
                Tween<double>(begin: 0.0, end: 1.0).chain(CurveTween(curve: Curves.easeOut));

            return SlideTransition(
              position: animation.drive(tween),
              child: FadeTransition(
                opacity: animation.drive(fadeTween),
                child: Container(
                  color: Colors.white,
                  child: child,
                ),
              ),
            );
          },
        ),
      ),
    ],
  );
});

int _getIndexForPath(String path) {
  if (path.startsWith('/home')) return 0;
  if (path.startsWith('/logs')) return 1;
  if (path.startsWith('/account')) return 2;
  return 0;
}
