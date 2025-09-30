import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'auth_text_field.dart';

class SignInForm extends StatefulWidget {
  const SignInForm({super.key, required this.onGoSignUp});
  final VoidCallback onGoSignUp;

  @override
  State<SignInForm> createState() => _SignInFormState();
}

class _SignInFormState extends State<SignInForm> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  static const green = Color(0xFF10B981);
  static const red   = Color(0xFFEF6A67);
  static const blue  = Color(0xFF3B82F6);

  bool _showPass = false;
  bool _loading = false;

  static final _emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  bool get _emailValid => _emailRegex.hasMatch(_email.text.trim());
  bool get _formReady => _emailValid && _password.text.isNotEmpty && !_loading;

  @override
  void initState() {
    super.initState();
    _email.addListener(() => setState(() {}));
    _password.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formReady) return;
    setState(() => _loading = true);
    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _email.text.trim(),
        password: _password.text,
      );

      final uid = cred.user!.uid;
      final snap = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final onboardingDone = (snap.data()?['onboardingComplete'] == true);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Welcome back!')),
      );
      context.go(onboardingDone ? '/home' : '/intro');

    } on FirebaseAuthException catch (e) {
      String msg = 'Sign in failed';
      switch (e.code) {
        case 'user-not-found': msg = 'No account found with that email.'; break;
        case 'wrong-password':
        case 'invalid-credential': msg = 'Incorrect email or password.'; break;
        case 'user-disabled': msg = 'This account has been disabled.'; break;
        case 'too-many-requests': msg = 'Too many attempts. Try again later.'; break;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _email.text.trim();
    if (!_emailValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid email first.')),
      );
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Password reset link sent to $email')),
      );
    } on FirebaseAuthException catch (e) {
      final msg = (e.code == 'user-not-found')
          ? 'No account found with that email.'
          : 'Could not send reset link. Try again.';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            const Text(
              'Welcome back',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Color(0xFF374151)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),

            PillTextFormField(
              controller: _email,
              hint: 'Email',
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              validator: (_) => _emailValid ? null : 'Enter a valid email',
              suffix: _email.text.isEmpty
                  ? null
                  : (_emailValid
                      ? const Icon(Icons.check_circle, color: green)
                      : const Icon(Icons.error_outline, color: red)),
            ),
            const SizedBox(height: 12),

            PillTextFormField(
              controller: _password,
              hint: 'Password',
              obscureText: !_showPass,
              textInputAction: TextInputAction.done,
              validator: (v) => (v != null && v.isNotEmpty) ? null : 'Enter your password',
              suffix: IconButton(
                icon: Icon(_showPass ? Icons.visibility_off : Icons.visibility, color: Colors.white70),
                onPressed: () => setState(() => _showPass = !_showPass),
              ),
            ),

            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _forgotPassword,
                child: const Text('Forgot password?'),
              ),
            ),
            const SizedBox(height: 6),

            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _formReady ? _signIn : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: blue,
                  disabledBackgroundColor: const Color(0xFF93C5FD),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _loading
                    ? const SizedBox(
                        height: 22, width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.6, valueColor: AlwaysStoppedAnimation(Colors.white)),
                      )
                    : const Text('Sign in',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ),

            const SizedBox(height: 12),
            TextButton(
              onPressed: widget.onGoSignUp,
              child: const Text(
                'Need an account?  Sign up',
                style: TextStyle(color: blue, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
