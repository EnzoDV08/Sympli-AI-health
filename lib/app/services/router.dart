import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sympli_ai_health/app/features/splash/splash_screen.dart';
import 'package:sympli_ai_health/app/features/onboarding/onboarding_screen.dart';
import 'package:sympli_ai_health/app/features/auth/screens/auth_screen.dart';
import 'package:sympli_ai_health/app/features/onboarding/health_intro_flow.dart';
import 'package:sympli_ai_health/app/features/home/home_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    debugLogDiagnostics: true,
    routes: [
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/auth',
        name: 'auth',
        builder: (context, state) => const AuthScreen(),
      ),
      GoRoute(
        path: '/intro',
        name: 'intro',
        builder: (context, state) => const HealthIntroFlow(),
      ),
      GoRoute(
        path: '/home',
        name: 'home',
        builder: (context, state) => const HomeScreen(),
      ),
    ],
  );
});
