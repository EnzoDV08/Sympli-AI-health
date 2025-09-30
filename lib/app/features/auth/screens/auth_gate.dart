import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snap.data == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) => context.go('/onboarding'));
        } else {
          WidgetsBinding.instance.addPostFrameCallback((_) => context.go('/home'));
        }
        return const SizedBox.shrink();
      },
    );
  }
}
