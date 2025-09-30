import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sympli_ai_health/app/features/auth/widgets/sign_in_form.dart';
import 'package:sympli_ai_health/app/features/auth/widgets/sign_up_form.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _controller = PageController();
  int _tab = 0; 

  static const slate = Color(0xFF0F172A);
  static const bg    = Color(0xFFF6F8FB);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final uri = GoRouterState.of(context).uri;
    final tab = uri.queryParameters['tab'];
    final initial = (tab == 'in') ? 1 : 0;
    if (_tab != initial) {
      _tab = initial;
      WidgetsBinding.instance.addPostFrameCallback((_) => _controller.jumpToPage(_tab));
    }
  }

  void _go(int index) {
    setState(() => _tab = index);
    _controller.animateToPage(index, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) context.go('/onboarding');
      },
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: bg,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: slate),
            onPressed: () => context.go('/onboarding'),
          ),
          titleSpacing: 0,
          title: _HeaderTitle(activeIndex: _tab),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
            child: Column(
              children: [
                Container(
                  height: 46,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF3F8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      _TabBtn(label: 'Sign up', active: _tab == 0, onTap: () => _go(0)),
                      _TabBtn(label: 'Sign in', active: _tab == 1, onTap: () => _go(1)),
                    ],
                  ),
                ),
                const SizedBox(height: 18),


                Expanded(
                  child: PageView(
                    controller: _controller,
                    onPageChanged: (i) => setState(() => _tab = i),
                    physics: const BouncingScrollPhysics(),
                    children: [
                      SignUpForm(onGoSignIn: () => _go(1)),
                      SignInForm(onGoSignUp: () => _go(0)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderTitle extends StatelessWidget {
  const _HeaderTitle({required this.activeIndex});
  final int activeIndex;

  static const blue  = Color(0xFF3B82F6);

  @override
  Widget build(BuildContext context) {
    final isUp = activeIndex == 0;
    final title = isUp ? 'Sign up' : 'Sign in';
    final subtitle = isUp ? 'create your account' : 'welcome back';

    return Row(
      children: [
        Container(width: 2, height: 28, margin: const EdgeInsets.only(right: 8), color: blue),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: blue)),
            const SizedBox(height: 2),
            const SizedBox(height: 0),
            const Text(' ', style: TextStyle(fontSize: 0)), 
            Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          ],
        ),
      ],
    );
  }
}

class _TabBtn extends StatelessWidget {
  const _TabBtn({required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;

  static const blue = Color(0xFF3B82F6); 

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? Colors.white : const Color(0xFFEFF3F8),
            borderRadius: BorderRadius.circular(12),
            boxShadow: active
                ? const [BoxShadow(blurRadius: 14, spreadRadius: -6, offset: Offset(0, 8), color: Color(0x14000000))]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(fontWeight: FontWeight.w700, color: active ? blue : const Color(0xFF64748B)),
          ),
        ),
      ),
    );
  }
}
