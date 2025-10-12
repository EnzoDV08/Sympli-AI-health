import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:sympli_ai_health/app/features/auth/widgets/auth_text_field.dart';
import 'package:sympli_ai_health/app/features/auth/services/auth_service.dart';



class SignUpForm extends StatefulWidget {
  const SignUpForm({super.key, required this.onGoSignIn});
  final VoidCallback onGoSignIn;

  @override
  State<SignUpForm> createState() => _SignUpFormState();
}

class _SignUpFormState extends State<SignUpForm> {
  final _formKey = GlobalKey<FormState>();

  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _repeat = TextEditingController();

  bool _showPass = false;
  bool _showRepeat = false;
  bool _agree = false;
  bool _loading = false;
  bool? _usernameTaken;
  bool? _emailExists; 
  Timer? _usernameDebounce;

  static const blue = Color(0xFF3B82F6);
  static const green = Color(0xFF10B981);
  static const red = Color(0xFFEF6A67);
  static const pillColor = Color(0xFF293241);
  static const hintColor = Color(0xFFB7C0CB);

  static final _emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
  static final _usernameRegex = RegExp(r'^[a-zA-Z0-9._-]{3,}$');

  bool get _emailValid => _emailRegex.hasMatch(_email.text.trim());
  bool get _usernameValid => _usernameRegex.hasMatch(_username.text.trim());

  bool get _hasLen => _password.text.length >= 8;
  bool get _hasUpper => RegExp(r'[A-Z]').hasMatch(_password.text);
  bool get _hasNum => RegExp(r'\d').hasMatch(_password.text);
  bool get _hasSym => RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(_password.text);
  bool get _match => _password.text.isNotEmpty && _password.text == _repeat.text;

  double get _strength {
    if (_password.text.isEmpty) return 0.0;
    int score = 0;
    if (_hasLen) score++;
    if (_hasUpper) score++;
    if (_hasNum) score++;
    if (_hasSym) score++;
    return (score / 4).clamp(0, 1).toDouble();
  }

  Color get _strengthColor {
    if (_strength >= .75) return green;
    if (_strength >= .5) return blue;
    return red;
  }

  bool get _availabilityOk =>
      _emailValid && _emailExists != true &&
      _usernameValid && (_usernameTaken == false);

  bool get _formReady =>
      _availabilityOk &&
      _hasLen && _hasUpper && _hasNum && _hasSym &&
      _match && _agree && !_loading;

  @override
  void initState() {
    super.initState();
    _username.addListener(_onUsernameChanged);
    _email.addListener(() {
      if (_emailExists != null) setState(() => _emailExists = null); 
    });
    _password.addListener(() => setState(() {}));
    _repeat.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _usernameDebounce?.cancel();
    _username.removeListener(_onUsernameChanged);
    _username.dispose();
    _email.dispose();
    _password.dispose();
    _repeat.dispose();
    super.dispose();
  }

  void _onUsernameChanged() {
    setState(() => _usernameTaken = null); 
    _usernameDebounce?.cancel();
    _usernameDebounce = Timer(const Duration(milliseconds: 350), () async {
      final value = _username.text.trim().toLowerCase();
      if (value.isEmpty || !_usernameRegex.hasMatch(value)) {
        setState(() => _usernameTaken = null);
        return;
      }
      try {
        final snap = await FirebaseFirestore.instance.collection('usernames').doc(value).get();
        setState(() => _usernameTaken = snap.exists);
      } catch (_) {
        setState(() => _usernameTaken = null);
      }
    });
  }

Future<void> _register() async {
  if (!_formReady) return;

  setState(() {
    _loading = true;
    _emailExists = null;
  });

  try {
    // ✅ Use your central AuthService to handle all creation logic
    final cred = await AuthService.instance.signUp(
      username: _username.text.trim(),
      email: _email.text.trim(),
      password: _password.text.trim(),
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Account created successfully!')),
    );

    // ✅ Optional small delay to ensure AuthState updates properly
    await Future.delayed(const Duration(milliseconds: 800));

    // Go to your next screen
    context.go('/intro');
  } on FirebaseAuthException catch (e) {
    String msg;
    switch (e.code) {
      case 'email-already-in-use':
        msg = 'Email already in use';
        setState(() => _emailExists = true);
        break;
      case 'invalid-email':
        msg = 'Invalid email';
        break;
      case 'weak-password':
        msg = 'Weak password';
        break;
      case 'username-already-in-use':
        msg = 'Username already taken';
        _onUsernameChanged();
        break;
      default:
        msg = e.message ?? 'Sign up failed. Please try again.';
    }

    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));
    }
  } catch (e, st) {
    debugPrint('🔥 Unexpected signup error: $e\n$st');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unexpected error. Please try again.')),
      );
    }
  } finally {
    if (mounted) setState(() => _loading = false);
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
          children: [
            const SizedBox(height: 12),
            const Text(
              'Create your Account',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Color(0xFF374151)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),

            PillTextFormField(
              controller: _username,
              hint: 'Username',
              textInputAction: TextInputAction.next,
              validator: (_) => _usernameValid ? null : '3+ chars, letters/digits . _ -',
              suffix: _AvailabilityIcon(status: _usernameTaken),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: _AvailabilityText(
                checking: _username.text.isNotEmpty && _usernameTaken == null && _usernameValid,
                ok: _usernameTaken == false && _usernameValid,
                bad: _usernameTaken == true,
                okText: 'Username available',
                badText: 'Username already taken',
              ),
            ),
            const SizedBox(height: 14),

            PillTextFormField(
              controller: _email,
              hint: 'Email',
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              validator: (_) => _emailValid ? null : 'Enter a valid email',
              suffix: _emailSuffix(),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(top: 6, left: 6),
                child: Text(
                  _email.text.isEmpty
                      ? ''
                      : (_emailExists == true
                          ? 'Email already in use'
                          : (_emailValid ? 'Looks valid' : '')),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _emailExists == true
                        ? red
                        : (_emailValid ? const Color(0xFF10B981) : const Color(0x00000000)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),

            PillTextFormField(
              controller: _password,
              hint: 'Password',
              obscureText: !_showPass,
              textInputAction: TextInputAction.next,
              suffix: IconButton(
                icon: Icon(_showPass ? Icons.visibility_off : Icons.visibility, color: Colors.white70),
                onPressed: () => setState(() => _showPass = !_showPass),
              ),
              validator: (_) => (_hasLen && _hasUpper && _hasNum && _hasSym)
                  ? null
                  : 'Try a stronger password',
            ),

            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: _strength,
                minHeight: 8,
                backgroundColor: const Color(0xFFF1F5F9),
                color: _strengthColor,
              ),
            ),
            const SizedBox(height: 10),
            _HintChecklist(items: [
              _HintItem('8+ characters', _hasLen),
              _HintItem('1 uppercase', _hasUpper),
              _HintItem('1 number', _hasNum),
              _HintItem('1 symbol', _hasSym),
            ]),
            const SizedBox(height: 14),

            PillTextFormField(
              controller: _repeat,
              hint: 'Repeat Password',
              obscureText: !_showRepeat,
              textInputAction: TextInputAction.done,
              suffix: IconButton(
                icon: Icon(_showRepeat ? Icons.visibility_off : Icons.visibility, color: Colors.white70),
                onPressed: () => setState(() => _showRepeat = !_showRepeat),
              ),
              validator: (_) => _match ? null : 'Passwords do not match',
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 150),
                style: TextStyle(
                  color: _repeat.text.isEmpty ? Colors.transparent : (_match ? green : red),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                child: Text(_repeat.text.isEmpty ? ' ' : (_match ? 'Passwords match' : 'Passwords do not match')),
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Checkbox(
                  value: _agree,
                  onChanged: (v) => setState(() => _agree = v ?? false),
                  activeColor: blue,
                ),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(color: Color(0xFF475569)),
                      children: [
                        const TextSpan(text: 'I agree to '),
                        TextSpan(
                          text: 'Term & Services',
                          style: const TextStyle(color: blue, fontWeight: FontWeight.w600),
                          recognizer: TapGestureRecognizer()..onTap = () {}),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _formReady ? _register : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: blue,
                  disabledBackgroundColor: const Color(0xFF93C5FD),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
                child: _loading
                    ? const SizedBox(
                        height: 22, width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.6, valueColor: AlwaysStoppedAnimation(Colors.white)),
                      )
                    : const Text('Register an Account',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ),

            const SizedBox(height: 12),
            TextButton(
              onPressed: widget.onGoSignIn,
              child: const Text(
                'Already have an account - Sign in',
                style: TextStyle(color: blue, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget? _emailSuffix() {
    if (_email.text.isEmpty) return null;
    if (_emailExists == true) {
      return const Icon(Icons.error_outline, color: red);
    }
    if (_emailValid) {
      return const Icon(Icons.check_circle, color: green);
    }
    return null;
  }
}

class _AvailabilityIcon extends StatelessWidget {
  const _AvailabilityIcon({required this.status});
  final bool? status; 

  @override
  Widget build(BuildContext context) {
    if (status == null) {
      return const Padding(
        padding: EdgeInsets.all(12.0),
        child: SizedBox(
          width: 16, height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2.2,
            valueColor: AlwaysStoppedAnimation(Color(0xFF94A3B8)),
          ),
        ),
      );
    }
    return Icon(
      status! ? Icons.error_outline : Icons.check_circle,
      color: status! ? _SignUpFormState.red : _SignUpFormState.green,
    );
  }
}

class _AvailabilityText extends StatelessWidget {
  const _AvailabilityText({
    required this.checking,
    required this.ok,
    required this.bad,
    required this.okText,
    required this.badText,
  });
  final bool checking, ok, bad;
  final String okText, badText;

  @override
  Widget build(BuildContext context) {
    String text = '';
    Color color = const Color(0x00000000);
    if (checking) {
      text = 'Checking…';
      color = const Color(0xFF94A3B8);
    } else if (ok) {
      text = okText;
      color = const Color(0xFF10B981);
    } else if (bad) {
      text = badText;
      color = const Color(0xFFEF6A67);
    }
    return Padding(
      padding: const EdgeInsets.only(top: 6, left: 6),
      child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

class _HintItem {
  final String label;
  final bool ok;
  const _HintItem(this.label, this.ok);
}

class _HintChecklist extends StatelessWidget {
  const _HintChecklist({required this.items});
  final List<_HintItem> items;

  @override
  Widget build(BuildContext context) {
    const okColor = Color(0xFF10B981);
    const badColor = Color(0xFF9CA3AF);
    return Column(
      children: items.map((e) {
        return Row(
          children: [
            Icon(e.ok ? Icons.check_circle : Icons.radio_button_unchecked,
                size: 18, color: e.ok ? okColor : badColor),
            const SizedBox(width: 8),
            Text(e.label, style: TextStyle(
              color: e.ok ? const Color(0xFF334155) : const Color(0xFF9CA3AF),
              fontWeight: e.ok ? FontWeight.w600 : FontWeight.w500,
            )),
          ],
        );
      }).toList(),
    );
  }
}
