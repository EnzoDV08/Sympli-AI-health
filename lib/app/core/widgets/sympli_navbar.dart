import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sympli_ai_health/app/features/notifications/notification_manager.dart';


class SympliNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onBellTap;

  const SympliNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.onBellTap,
  });

  @override
  Widget build(BuildContext context) {
    const darkBg = Color(0xFF2F3A4D);
    const inactive = Color(0xFF9AA7B8);

    final currentPath = GoRouterState.of(context).uri.toString();

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 18),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: BoxDecoration(
                  color: darkBg,
                  borderRadius: BorderRadius.circular(40),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _NavItem(
                      icon: Icons.home_rounded,
                      label: "Home",
                      active: currentPath == '/home',
                      onTap: () => context.go('/home'),
                    ),
                    _NavItem(
                      icon: Icons.history_rounded,
                      label: "Chats",
                      active: currentPath == '/logs',
                      onTap: () => context.go('/logs'),
                    ),
                    _NavItem(
                      icon: Icons.person_rounded,
                      label: "Account",
                      active: currentPath == '/account',
                      onTap: () => context.go('/account'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),

              StreamBuilder<List<Map<String, dynamic>>>(
                stream: notificationManager.stream,        // listens to all updates
                initialData: notificationManager.all,      // start with current notifications
                builder: (context, snapshot) {
                  // ✅ Count all notifications, not just unread
                  final total = notificationManager.all.length;

                  return InkWell(
                    onTap: onBellTap,                       // when user taps bell
                    borderRadius: BorderRadius.circular(40),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // Bell background and icon
                        Container(
                          padding: const EdgeInsets.all(17),
                          decoration: const BoxDecoration(
                            color: darkBg,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Color(0x33000000),
                                blurRadius: 10,
                                offset: Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.notifications_rounded,
                            color: inactive,
                            size: 26,
                          ),
                        ),

                        // 🔴 Red badge showing total number
                        if (total > 0)
                          Positioned(
                            right: 8,
                            top: 8,
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: const BoxDecoration(
                                color: Colors.redAccent,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                // show 9+ if more than 9 notifications
                                total > 9 ? '9+' : total.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),



          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const inactive = Color(0xFF9AA7B8);
    const activeColor = Color(0xFF3B82F6);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            Icon(icon, size: 20, color: active ? activeColor : inactive),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: active ? activeColor : inactive,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
