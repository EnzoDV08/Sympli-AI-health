import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  // Layout constants
  static const double kTopGap = 44;
  static const double kCardHeight = 380;
  static const double kImageHeight = 260;
  static const double kDotsTopPad = 28;
  static const double kTitleTopPad = 32;
  static const double kCtasTopGap = 32;
  static const double kBottomGap = 36;
  static const double kTitleBoxHeight = 36;
  static const double kSubtitleBoxHeight = 44;

  // Bubble (backdrop) FX
  static const double bubbleDiameter = 320;
  static const double bubbleBlur = 48;
  static const double bubbleOpacity = 0.38;
  static const Duration bubbleAnim = Duration(milliseconds: 420);

  final _pageController = PageController(viewportFraction: 0.92);
  Timer? _autoTimer;
  int _index = 0;

  // Colors
  static const slate = Color(0xFF0F172A);
  static const blue = Color(0xFF3B82F6);
  static const emerald = Color(0xFF10B981);
  static const coral = Color(0xFFEF6A67);
  static const muted = Color(0xFFCBD5E1);

  // Slides
  final _slides = const [
    (img: 'assets/images/Sympli_Bot.png', title: 'Sympli Chat',             subtitle: 'Ask anything — triage, meds, symptoms and more.'),
    (img: 'assets/images/Reminder.png',   title: 'Reminders',               subtitle: 'Never miss a dose. Smart alerts you can trust.'),
    (img: 'assets/images/Simplified.png', title: 'Your Health, Simplified', subtitle: 'Log symptoms and meds with one tap.'),
  ];

  final List<Color> _bubbleColors = const [emerald, blue, coral];

  bool _warmedUp = false;

  // Made synchronous: no awaits, so no BuildContext across async gaps.
  void _warmUp() {
    for (final s in _slides) {
      precacheImage(AssetImage(s.img), context);
    }
    precacheImage(const AssetImage('assets/images/Google_Logo.png'), context);

    // Flip the flag on the next frame (no async gaps here)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _warmedUp = true);
    });
  }

  @override
  void initState() {
    super.initState();

    // Auto-advance slides
    _autoTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      final next = (_index + 1) % _slides.length;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeOutCubic,
      );
    });

    // Warm-up images after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _warmUp();
    });
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isSmall = size.height < 740;

    final topGap = isSmall ? kTopGap - 8 : kTopGap;
    final cardHeight = isSmall ? kCardHeight - 24 : kCardHeight;
    final imageH = isSmall ? kImageHeight - 16 : kImageHeight;
    final dotsPad = isSmall ? kDotsTopPad - 6 : kDotsTopPad;
    final titlePad = isSmall ? kTitleTopPad - 6 : kTitleTopPad;
    final ctasGap = isSmall ? kCtasTopGap - 8 : kCtasTopGap;
    final bottomGap = isSmall ? kBottomGap - 10 : kBottomGap;

    final currentTitle = _slides[_index].title;
    final currentSubtitle = _slides[_index].subtitle;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Column(
                  children: [
                    SizedBox(height: topGap),

                    // Card area with bubble + image pager
                    SizedBox(
                      height: cardHeight,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Bubble background
                          AnimatedContainer(
                            duration: bubbleAnim,
                            curve: Curves.easeOut,
                            width: bubbleDiameter,
                            height: bubbleDiameter,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _bubbleColors[_index].withValues(alpha: bubbleOpacity),
                            ),
                          ),
                          // Blur only after warm-up to avoid jank
                          Positioned.fill(
                            child: IgnorePointer(
                              child: _warmedUp
                                  ? BackdropFilter(
                                      filter: ui.ImageFilter.blur(
                                        sigmaX: bubbleBlur,
                                        sigmaY: bubbleBlur,
                                      ),
                                      child: const SizedBox.shrink(),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ),
                          // Slides
                          PageView.builder(
                            controller: _pageController,
                            itemCount: _slides.length,
                            physics: const BouncingScrollPhysics(),
                            allowImplicitScrolling: true,
                            onPageChanged: (i) => setState(() => _index = i),
                            itemBuilder: (_, i) {
                              final img = _slides[i].img;
                              return Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: Image.asset(
                                    img,
                                    height: imageH,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) => const Icon(
                                      Icons.image_outlined,
                                      size: 120,
                                      color: Colors.black26,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    // Dots
                    Padding(
                      padding: EdgeInsets.only(top: dotsPad),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(_slides.length, (i) {
                          final active = i == _index;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            margin: const EdgeInsets.symmetric(horizontal: 6),
                            width: active ? 36 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: active ? _bubbleColors[_index] : muted,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          );
                        }),
                      ),
                    ),

                    // Title + Subtitle
                    Padding(
                      padding: EdgeInsets.fromLTRB(24, titlePad, 24, 0),
                      child: Opacity(
                        opacity: _warmedUp ? 1 : 0,
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 120),
                          opacity: 1,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              FancyTextSwitcher(
                                text: currentTitle,
                                height: kTitleBoxHeight,
                                inDx: -10,
                                outDx: 10,
                                inDy: -4,
                                outDy: 4,
                                inScaleFrom: 1.015,
                                outScaleTo: .985,
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  color: slate,
                                  height: 1.15,
                                ),
                              ),
                              const SizedBox(height: 6),
                              FancyTextSwitcher(
                                text: currentSubtitle,
                                height: kSubtitleBoxHeight,
                                alignTop: true,
                                inDx: -8,
                                outDx: 8,
                                inDy: -2,
                                outDy: 2,
                                inScaleFrom: 1.01,
                                outScaleTo: .99,
                                blurSigma: 0.8,
                                style: const TextStyle(
                                  fontSize: 15,
                                  height: 1.35,
                                  color: Color(0xFF475569),
                                ),
                                maxLines: 2,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const Divider(indent: 24, endIndent: 24),
                    SizedBox(height: ctasGap),

                    // CTAs
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          SizedBox(
                            height: 56,
                            width: double.infinity,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Color(0xFFE2E8F0)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                backgroundColor: Colors.white,
                              ),
                              onPressed: () => context.go('/auth?tab=in'),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Image.asset(
                                    'assets/images/Google_Logo.png',
                                    width: 30,
                                    height: 30,
                                    errorBuilder: (_, __, ___) => const Icon(
                                      Icons.g_mobiledata,
                                      color: Colors.black54,
                                      size: 30,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Text(
                                    'Continue with Google',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: slate,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            height: 56,
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: blue,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              onPressed: () => context.go('/auth?tab=up'),
                              child: const Text(
                                'Get started',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextButton(
                            onPressed: () => context.go('/auth?tab=in'),
                            child: const Text(
                              'I already have an account – Sign in',
                              style: TextStyle(
                                color: blue,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: bottomGap),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ---------- FancyTextSwitcher (top-level widget) ----------
class FancyTextSwitcher extends StatefulWidget {
  final String text;
  final TextStyle style;
  final double height;
  final int maxLines;
  final bool alignTop;
  final double inDx, outDx, inDy, outDy;
  final double inScaleFrom, outScaleTo;
  final double blurSigma;

  const FancyTextSwitcher({
    super.key,
    required this.text,
    required this.style,
    required this.height,
    this.maxLines = 1,
    this.alignTop = false,
    this.inDx = -8,
    this.outDx = 8,
    this.inDy = -3,
    this.outDy = 3,
    this.inScaleFrom = 1.01,
    this.outScaleTo = .99,
    this.blurSigma = 1.0,
  });

  @override
  State<FancyTextSwitcher> createState() => _FancyTextSwitcherState();
}

class _FancyTextSwitcherState extends State<FancyTextSwitcher>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late String _oldText;
  late String _newText;

  @override
  void initState() {
    super.initState();
    _oldText = widget.text;
    _newText = widget.text;
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void didUpdateWidget(covariant FancyTextSwitcher old) {
    super.didUpdateWidget(old);
    if (old.text != widget.text) {
      _oldText = _newText;
      _newText = widget.text;
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final align = widget.alignTop ? Alignment.topLeft : Alignment.centerLeft;

    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) {
          final t = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic).value;

          final inOpacity = t;
          final inDx = (1 - t) * widget.inDx;
          final inDy = (1 - t) * widget.inDy;
          final inScale = widget.inScaleFrom + (1 - widget.inScaleFrom) * t;
          final inBlur = (1 - t) * widget.blurSigma;

          final outOpacity = 1 - t;
          final outDx = t * widget.outDx;
          final outDy = t * widget.outDy;
          final outScale = 1 - (1 - widget.outScaleTo) * t;
          final outBlur = t * widget.blurSigma;

          return Stack(
            alignment: align,
            children: [
              if (_c.isAnimating || _oldText != _newText)
                Opacity(
                  opacity: outOpacity,
                  child: Transform.translate(
                    offset: Offset(outDx, outDy),
                    child: Transform.scale(
                      scale: outScale,
                      alignment: Alignment.centerLeft,
                      child: ImageFiltered(
                        imageFilter: ui.ImageFilter.blur(
                          sigmaX: outBlur,
                          sigmaY: outBlur,
                        ),
                        child: _buildText(_oldText),
                      ),
                    ),
                  ),
                ),
              Opacity(
                opacity: inOpacity,
                child: Transform.translate(
                  offset: Offset(inDx, inDy),
                  child: Transform.scale(
                    scale: inScale,
                    alignment: Alignment.centerLeft,
                    child: ImageFiltered(
                      imageFilter: ui.ImageFilter.blur(
                        sigmaX: inBlur,
                        sigmaY: inBlur,
                      ),
                      child: _buildText(_newText),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildText(String s) => Text(
        s,
        maxLines: widget.maxLines,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.left,
        style: widget.style,
      );
}
