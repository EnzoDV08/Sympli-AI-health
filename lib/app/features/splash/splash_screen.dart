import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 14))
        ..repeat(); 

  @override
  void initState() {
    super.initState();
    Timer(const Duration(milliseconds: 3200), () {
      if (!mounted) return;
      context.go('/onboarding');
    });
  }

  bool _didPrecache = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didPrecache) {
      precacheImage(const AssetImage('assets/images/sympli_logo.png'), context);
      _didPrecache = true;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fadeIn = CurvedAnimation(parent: _c, curve: const Interval(0, 0.25, curve: Curves.easeOut));
    final pop = Tween<double>(begin: 0.9, end: 1.0)
        .animate(CurvedAnimation(parent: _c, curve: const Interval(0, 0.2, curve: Curves.easeOutBack)));

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _GradientBackground(),

          
          AnimatedBuilder(
            animation: _c,
            builder: (_, __) {
              final t = _c.value * 2 * math.pi;
              return Stack(children: [
                
                _BokehBlob(
                  baseLeft: 24,
                  baseTop: 80,
                  dx: math.sin(t * 0.7) * 26,
                  dy: math.cos(t * 0.6) * 18,
                  size: 260,
                  blurSigma: 60,
                  colors: const [Color(0xFF58E4CF), Color(0x0058E4CF)],
                ),
                
                _BokehBlob(
                  baseRight: -10,
                  baseTop: 40,
                  dx: math.sin(t * 0.6 + 0.8) * 30,
                  dy: math.cos(t * 0.5 + 0.4) * 22,
                  size: 230,
                  blurSigma: 50,
                  colors: const [Color(0xFF7FD9FF), Color(0x007FD9FF)],
                ),
              
                _BokehBlob(
                  baseLeft: -20,
                  baseBottom: -10,
                  dx: math.cos(t * 0.9) * 24,
                  dy: math.sin(t * 0.8) * 26,
                  size: 320,
                  blurSigma: 72,
                  colors: const [Color(0xFFB9F7FF), Color(0x00B9F7FF)],
                ),
                _BokehBlob(
                  baseRight: -30,
                  baseBottom: -20,
                  dx: math.sin(t * 1.0 + 1.2) * 22,
                  dy: math.cos(t * 0.9 + 0.6) * 22,
                  size: 280,
                  blurSigma: 64,
                  colors: const [Color(0xFF38BDF8), Color(0x0038BDF8)],
                ),
              ]);
            },
          ),

          Center(
            child: FadeTransition(
              opacity: fadeIn,
              child: ScaleTransition(
                scale: pop,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/images/sympli_logo.png',
                      width: 300,
                      filterQuality: FilterQuality.high,
                    ),
                    const SizedBox(height: 22),
                    const SizedBox(
                      width: 26,
                      height: 26,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


class _GradientBackground extends StatelessWidget {
  const _GradientBackground();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFFA5F0E6), 
            Color(0xFFB9E9FF), 
          ],
        ),
      ),
    );
  }
}


class _BokehBlob extends StatelessWidget {
  const _BokehBlob({
    this.baseLeft,
    this.baseRight,
    this.baseTop,
    this.baseBottom,
    required this.dx,
    required this.dy,
    required this.size,
    required this.blurSigma,
    required this.colors,
  });

  final double? baseLeft, baseRight, baseTop, baseBottom;
  final double dx, dy;
  final double size;
  final double blurSigma;
  final List<Color> colors; 

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: baseLeft != null ? baseLeft! + dx : null,
      right: baseRight != null ? baseRight! - dx : null,
      top: baseTop != null ? baseTop! + dy : null,
      bottom: baseBottom != null ? baseBottom! - dy : null,
      child: IgnorePointer(
        child: ImageFiltered(
          
          imageFilter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: colors,
                stops: const [0.0, 1.0],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
