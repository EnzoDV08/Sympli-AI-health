import 'package:flutter/material.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Onboarding')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.health_and_safety, size: 80),
            SizedBox(height: 16),
            Text(
              'Welcome to Sympli!',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Text(
              'This is the onboarding screen.\nYou’re seeing me because routing works.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
