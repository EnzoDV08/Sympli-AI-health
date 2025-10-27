import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sympli_ai_health/app/core/widgets/ask_bar.dart';
import 'package:sympli_ai_health/app/core/widgets/quick_ask_section.dart';
import 'package:sympli_ai_health/app/features/home/widgets/medication_reminder_widget.dart';
import 'package:go_router/go_router.dart';

const _kHeaderBg = 'assets/images/header_bg_grain.png';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const bg = Color(0xFFF6F8FB);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      backgroundColor: bg,
      body: const _HomeTab(),
    );
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab();

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom + 80; 

    return SafeArea(
      top: false,
      bottom: false,
      child: SingleChildScrollView(
        clipBehavior: Clip.none,
        padding: EdgeInsets.only(bottom: bottomPadding), 
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _HeaderCard(),
            const SizedBox(height: 16),

            const SizedBox(height: 8),
            AskBar(),

            const SizedBox(height: 20),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: QuickAskSection(
                onSelect: (label) {
                  debugPrint("Quick Ask selected: $label");
                  context.pushNamed(
                    'chat-ai',
                    extra: {'followUpCondition': label},
                  );
                },
              ),
            ),



            const SizedBox(height: 12),

            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, top: 4, bottom: 6),
              child: Row(
                children: const [
                  Icon(
                    CupertinoIcons.bell_fill,
                    color: Color(0xFF5C8CFF),
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Text(
                    "Reminders",
                    style: TextStyle(
                      color: Color(0xFF3B5FFF),
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          const MedicationReminderWidget(),
          ],
        ),
      ),
    );
  }
}


class _HeaderCard extends StatelessWidget {
  const _HeaderCard();

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    const bottomRadius = 96.0;
    final headerHeight = 320.0 + topInset;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      height: headerHeight,
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(bottomRadius),
          bottomRight: Radius.circular(bottomRadius),
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const _HeaderBackground(),
          Padding(
            padding: EdgeInsets.only(top: topInset),
            child: Stack(
              children: const [
                _HeaderTopRow(),
                _HeaderCenterBlock(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderCenterBlock extends StatelessWidget {
  const _HeaderCenterBlock();

  @override
  Widget build(BuildContext context) {
    const logoSize = 115.0;
    const haloSize = 124.0;

    return Positioned.fill(
      child: Align(
        alignment: const Alignment(-0.2, 0.44),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Transform.translate(
                  offset: const Offset(15, 0),
                  child: Container(
                    width: haloSize,
                    height: haloSize,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x33000000),
                          blurRadius: 20,
                          spreadRadius: 6,
                          offset: Offset(0, 8),
                        ),
                        BoxShadow(
                          color: Color(0x66FFFFFF),
                          blurRadius: 25,
                          spreadRadius: 6,
                        ),
                      ],
                    ),
                  ),
                ),
                Transform.translate(
                  offset: const Offset(15, 0),
                  child: Opacity(
                    opacity: 0.9,
                    child: Image.asset(
                      'assets/images/Sympli_Single_Logo.png',
                      width: logoSize,
                      height: logoSize,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Transform.translate(
              offset: const Offset(2, 0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Transform.translate(
                    offset: const Offset(5, -15),
                    child: Transform.rotate(
                      angle: -0.26,
                      child: Image.asset(
                        'assets/images/Sympli_Bot.png',
                        width: 45,
                        height: 45,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Image.asset(
                          'assets/icons/ic_bot.png',
                          width: 34,
                          height: 34,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    "Welcome to\nSympli Chat",
                    textAlign: TextAlign.left,
                    style: TextStyle(
                      color: Color(0xFF24303B),
                      height: 1.15,
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.1,
                      shadows: [
                        Shadow(
                          blurRadius: 2,
                          color: Color(0x26FFFFFF),
                          offset: Offset(0, 1),
                        ),
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

class _HeaderBackground extends StatelessWidget {
  const _HeaderBackground();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        image: DecorationImage(
          image: AssetImage(_kHeaderBg),
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
        ),
      ),
      child: Container(color: Colors.black.withValues(alpha: 0.02)),
    );
  }
}

class _HeaderTopRow extends StatelessWidget {
  const _HeaderTopRow();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final name = _bestName(user);

    return Positioned(
      left: 18,
      top: 18,
      right: 18,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _UserAvatar(user: user, radius: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hello $name',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'How are you feeling today?',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const _EmsPill(),
        ],
      ),
    );
  }
}

class _UserAvatar extends StatelessWidget {
  const _UserAvatar({required this.user, this.radius = 20});
  final User? user;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final photo = user?.photoURL ?? '';
    final hasPhoto = photo.trim().isNotEmpty;

    Widget placeholder() => Icon(
          CupertinoIcons.person_alt_circle_fill,
          color: Colors.black54,
          size: radius * 1.8,
        );

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: .25),
      ),
      child: CircleAvatar(
        radius: radius,
        backgroundColor: Colors.white,
        backgroundImage: hasPhoto ? NetworkImage(photo) : null,
        child: hasPhoto
            ? null
            : ClipOval(
                child: Image.asset(
                  'assets/icons/ic_avatar_placeholder.png',
                  width: radius * 2,
                  height: radius * 2,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => placeholder(),
                ),
              ),
      ),
    );
  }
}

String _bestName(User? user) {
  final dn = user?.displayName?.trim();
  if (dn != null && dn.isNotEmpty) return dn;
  final email = user?.email?.trim() ?? '';
  if (email.isNotEmpty && email.contains('@')) {
    final raw = email.split('@').first;
    if (raw.isNotEmpty) {
      return raw
          .replaceAll('.', ' ')
          .split(' ')
          .where((p) => p.isNotEmpty)
          .map((p) =>
              p[0].toUpperCase() + (p.length > 1 ? p.substring(1).toLowerCase() : ''))
          .join(' ');
    }
  }
  return 'there';
}

class _EmsPill extends StatelessWidget {
  const _EmsPill();

  Future<void> _dialAmbulance(BuildContext context) async {
    final uri = Uri(scheme: 'tel', path: '10177');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dial 10177 (ambulance)')),
        );
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dial 10177 (ambulance)')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(26),
      onTap: () => _dialAmbulance(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFFF758F),
          borderRadius: BorderRadius.circular(26),
          boxShadow: const [
            BoxShadow(color: Color(0x33000000), blurRadius: 8, offset: Offset(0, 3)),
          ],
        ),
        child: Row(
          children: [
            Image.asset(
              'assets/icons/ic_phone.png',
              width: 16,
              height: 16,
              color: Colors.white,
              errorBuilder: (_, __, ___) =>
                  const Icon(CupertinoIcons.phone_fill, size: 16, color: Colors.white),
            ),
            const SizedBox(width: 8),
            const Text(
              "EMS",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}
