import 'package:flutter/material.dart';

class GlassCard extends StatelessWidget {
  const GlassCard({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .9),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            blurRadius: 24,
            spreadRadius: -8,
            offset: Offset(0, 12),
            color: Color(0x1A000000),
          )
        ],
        border: Border.all(color: const Color(0x11FFFFFF)),
      ),
      child: child,
    );
  }
}
