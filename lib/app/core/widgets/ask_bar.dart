import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AskBar extends StatelessWidget {
  const AskBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: 'ask-bar',
      flightShuttleBuilder: (flightContext, animation, direction, fromContext, toContext) {
        return AnimatedBuilder(
          animation: animation,
          builder: (context, child) {
            final slideY = Tween<double>(begin: 0, end: 100).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeInOutCubic,
            ));
            return Transform.translate(
              offset: Offset(0, direction == HeroFlightDirection.push ? slideY.value : -slideY.value),
              child: Opacity(
                opacity: animation.value,
                child: child,
              ),
            );
          },
          child: _buildBar(context),
        );
      },
      child: GestureDetector(
        onTap: () => context.push('/chat-ai'),
        child: _buildBar(context),
      ),
    );
  }

  Widget _buildBar(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(30),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
        backgroundBlendMode: BlendMode.overlay,
      ),
      child: Row(
        children: const [
          Icon(Icons.psychology_rounded, color: Color(0xFF37B7A5)),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              "Ask Sympli AI anything...",
              style: TextStyle(
                fontSize: 16,
                color: Colors.black54,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Icon(Icons.arrow_upward_rounded, color: Color(0xFF37B7A5), size: 22),
        ],
      ),
    );
  }
}
