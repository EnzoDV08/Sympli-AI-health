import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sympli_ai_health/app/features/meds/services/med_reminder_service.dart';

class HealthIntroFlow extends StatefulWidget {
  const HealthIntroFlow({super.key});
  @override
  State<HealthIntroFlow> createState() => _HealthIntroFlowState();
}

class _HealthIntroFlowState extends State<HealthIntroFlow>
    with TickerProviderStateMixin {
  final _page = PageController();
  int _index = 0;

  String? _gender;
  String? _ageRange;
  final Set<String> _conditions = {};
  final Set<String> _allergies = {};
  final Set<String> _meds = {};
  final Map<String, Map<String, dynamic>> _medPlans = {}; 

  bool _saving = false;
  bool _finishing = false;

  late final AnimationController _bgCtrl;

  static const bg = Color(0xFFF6F8FB);
  static const blue = Color(0xFF3B82F6);
  static const slate = Color(0xFF0F172A);

  @override
  void initState() {
    super.initState();
    _bgCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat();
  }

  @override
  void dispose() {
    _page.dispose();
    _bgCtrl.dispose();
    super.dispose();
  }

  bool get _validStep {
    switch (_index) {
      case 0:
        return _gender != null && int.tryParse(_ageRange ?? '') != null;
      case 1:
        return _conditions.isNotEmpty;
      case 2:
        return _allergies.isNotEmpty || _meds.isNotEmpty;
      default:
        return true;
    }
  }


  double get _progress => (_index + (_validStep ? .8 : .2)) / 3.0;

  Future<void> _finish() async {
    if (!_validStep || _saving) return;
    setState(() => _saving = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception('No user');

      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'onboardingComplete': true,
        'profile': {
          'gender': _gender,
          'age': int.tryParse(_ageRange ?? ''),
          'conditions': _conditions.toList(),
          'allergies': _allergies.toList(),
          'medications': _meds.toList(),
          'medicationSchedules': _medPlans.map((k, v) => MapEntry(k, {
            'repeat': v['repeat'],       
            'time': v['time'],            
            if (v['n'] != null) 'n': v['n'],
            if (v['days'] != null) 'days': (v['days'] as Set<int>? ?? (v['days'] as List?)?.cast<int>() ?? <int>[]).toList(),
            'timezone': DateTime.now().timeZoneName,
          })),
        },
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      setState(() => _finishing = true);
      await Future.delayed(const Duration(milliseconds: 950));
      if (mounted) context.go('/home');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.of(context).viewPadding.bottom;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: bg,
        titleSpacing: 10,
        title: Row(
          children: [
            Container(width: 2, height: 26, color: blue),
            const SizedBox(width: 8),
            const Text(
              "Let’s personalize Sympli",
              style: TextStyle(color: blue, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => context.go('/home'),
            child: const Text('Skip',
                style: TextStyle(
                    color: Color(0xFF64748B), fontWeight: FontWeight.w700)),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(10),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: _progress.clamp(0, 1)),
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOut,
                builder: (_, v, __) => LinearProgressIndicator(
                  value: v,
                  minHeight: 8,
                  backgroundColor: const Color(0xFFE8EEF9),
                  valueColor: const AlwaysStoppedAnimation(blue),
                ),
              ),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          _LiquidBackground(controller: _bgCtrl),

          Column(
            children: [
              const SizedBox(height: 6),
              Expanded(
                child: PageView(
                  controller: _page,
                  onPageChanged: (i) => setState(() => _index = i),
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _GlassCard(
                      child: _StepBasics(
                        gender: _gender,
                        ageRange: _ageRange,
                        onSelectGender: (v) => setState(() => _gender = v),
                        onSelectAge: (v) => setState(() => _ageRange = v),
                      ),
                    ),
                    _GlassCard(
                      child: _StepMulti(
                        title: 'Any chronic conditions?',
                        hint: 'Type and tap Add…',
                        selected: _conditions,
                        common: const [
                          'Hypertension',
                          'Diabetes',
                          'Asthma',
                          'Anxiety',
                          'Depression',
                          'GERD'
                        ],
                        icon: Icons.favorite_rounded,
                        onChanged: () => setState(() {}),
                      ),
                    ),
                    _GlassCard(
                      child: _StepAllergyMeds(
                        allergies: _allergies,
                        meds: _meds,
                        medPlans: _medPlans, 
                        onChanged: () => setState(() {}),
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: EdgeInsets.fromLTRB(
                    16, 6, 16, 12 + (safeBottom > 0 ? safeBottom : 8)),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _index == 0
                            ? null
                            : () => _page.previousPage(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeOut,
                                ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                          foregroundColor: const Color(0xFF334155),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('Back'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: !_validStep
                            ? null
                            : () async {
                                if (_index < 2) {
                                  await _page.nextPage(
                                      duration:
                                          const Duration(milliseconds: 300),
                                      curve: Curves.easeOut);
                                } else {
                                  await _finish();
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: blue,
                          disabledBackgroundColor: const Color(0xFF93C5FD),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: _saving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                    valueColor:
                                        AlwaysStoppedAnimation(Colors.white)),
                              )
                            : Text(_index < 2 ? 'Next' : 'Done',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (i) {
                  final active = _index == i;
                  return AnimatedScale(
                    duration: const Duration(milliseconds: 220),
                    scale: active ? 1.06 : 1.0,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 240),
                      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                      width: active ? 22 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: active ? blue : const Color(0xFFD5E2FA),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 8),
            ],
          ),

          IgnorePointer(
            ignoring: !_finishing,
            child: AnimatedOpacity(
              opacity: _finishing ? 1 : 0,
              duration: const Duration(milliseconds: 280),
              child: Stack(
                children: [
                  Container(color: Colors.white.withValues(alpha: .9)),
                  Center(
                    child: _PulseBadge(
                      color: blue,
                      child: const Icon(Icons.check_rounded,
                          color: Colors.white, size: 56),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LiquidBackground extends StatelessWidget {
  const _LiquidBackground({required this.controller});
  final Animation<double> controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) {
        final t = controller.value * 2 * math.pi;
        final dx1 = math.sin(t * 0.7) * 24;
        final dy1 = math.cos(t * 0.6) * 18;

        final dx2 = math.sin(t * 0.55 + 0.8) * 26;
        final dy2 = math.cos(t * 0.5 + 0.4) * 20;

        final dx3 = math.cos(t * 0.9) * 22;
        final dy3 = math.sin(t * 0.85) * 22;

        return Stack(
          fit: StackFit.expand,
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFA5F0E6), 
                    Color(0xFFB9E9FF), 
                  ],
                ),
              ),
            ),

            _BokehBlob(
              baseLeft: 20,
              baseTop: 80,
              dx: dx1, dy: dy1,
              size: 260,
              blurSigma: 60,
              colors: const [Color(0xFF58E4CF), Color(0x0058E4CF)],
            ),
            _BokehBlob(
              baseRight: -12,
              baseTop: 36,
              dx: dx2, dy: dy2,
              size: 230,
              blurSigma: 52,
              colors: const [Color(0xFF7FD9FF), Color(0x007FD9FF)],
            ),
            _BokehBlob(
              baseLeft: -18,
              baseBottom: -12,
              dx: dx3, dy: dy3,
              size: 310,
              blurSigma: 68,
              colors: const [Color(0xFF38BDF8), Color(0x0038BDF8)],
            ),

            IgnorePointer(
              ignoring: true,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.center,
                    colors: [
                      Colors.white.withValues(alpha: 0.08),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
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
          imageFilter: ui.ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
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


class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final maxW = 640.0;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxW),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Stack(
              children: [
                BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .66),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: .55),
                        width: 1,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x1A000000),
                          blurRadius: 24,
                          offset: Offset(0, 12),
                        ),
                      ],
                    ),
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: child,
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 14,
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withValues(alpha: .55),
                            Colors.white.withValues(alpha: 0),
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
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

class _StepBasics extends StatefulWidget {
  const _StepBasics({
    required this.gender,
    required this.ageRange,
    required this.onSelectGender,
    required this.onSelectAge,
  });

  final String? gender;
  final String? ageRange;             
  final ValueChanged<String> onSelectGender;
  final ValueChanged<String> onSelectAge;

  @override
  State<_StepBasics> createState() => _StepBasicsState();
}

class _StepBasicsState extends State<_StepBasics> {
  late final TextEditingController _ageCtrl =
      TextEditingController(text: widget.ageRange ?? '');

  @override
  void dispose() {
    _ageCtrl.dispose();
    super.dispose();
  }

  int _currentAge() => int.tryParse(_ageCtrl.text) ?? 25;

  void _setAge(int value) {
    final v = value.clamp(1, 120);
    _ageCtrl.text = '$v';
    widget.onSelectAge('$v');
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final age = _currentAge();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _H2('Tell us a bit about you'),
        const _Sub('Pick your gender and enter your age.'),

        const _H3('Gender'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _LiquidChip(
              icon: Icons.male_rounded,
              label: 'Male',
              selected: widget.gender == 'Male',
              onTap: () => widget.onSelectGender('Male'),
            ),
            _LiquidChip(
              icon: Icons.female_rounded,
              label: 'Female',
              selected: widget.gender == 'Female',
              onTap: () => widget.onSelectGender('Female'),
            ),
          ],
        ),

        const SizedBox(height: 20),

        const _H3('Age'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F7FB),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              IconButton.filledTonal(
                onPressed: () => _setAge(age - 1),
                icon: const Icon(Icons.remove),
                style: IconButton.styleFrom(shape: const CircleBorder()),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _ageCtrl,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24, fontWeight: FontWeight.w800, color: _HealthIntroFlowState.slate),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Age',
                  ),
                  onChanged: (v) {
                    final n = int.tryParse(v);
                    if (n != null && n >= 1 && n <= 120) {
                      widget.onSelectAge('$n');
                      setState(() {});
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                onPressed: () => _setAge(age + 1),
                icon: const Icon(Icons.add),
                style: IconButton.styleFrom(shape: const CircleBorder()),
              ),
            ],
          ),
        ),

        const SizedBox(height: 6),
        const _Sub('You can type your age or use the buttons (1–120).'),
      ],
    );
  }
}


class _StepMulti extends StatefulWidget {
  const _StepMulti({
    required this.title,
    required this.hint,
    required this.selected,
    required this.common,
    required this.icon,
    required this.onChanged,
  });

  final String title;
  final String hint;
  final Set<String> selected;
  final List<String> common;
  final IconData icon;
  final VoidCallback onChanged;

  @override
  State<_StepMulti> createState() => _StepMultiState();
}

class _StepMultiState extends State<_StepMulti> {
  final _ctrl = TextEditingController();

    @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _addFromField() {
    final v = _ctrl.text.trim();
    if (v.isEmpty) return;
    widget.selected.add(_titleCase(v));
    _ctrl.clear();
    widget.onChanged();
    setState(() {});
  }

  String _titleCase(String s) =>
      s.split(' ').where((p) => p.isNotEmpty).map((p) {
        final f = p[0].toUpperCase();
        final r = p.substring(1).toLowerCase();
        return '$f$r';
      }).join(' ');


  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _H2(widget.title),
        const _Sub('Tap to add or select common ones below.'),
        const SizedBox(height: 12),

        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: widget.selected
              .map((s) => _Tag(
                    text: s,
                    onRemove: () {
                      widget.selected.remove(s);
                      widget.onChanged();
                      setState(() {});
                    },
                  ))
              .toList(),
        ),
        const SizedBox(height: 10),

        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                decoration: InputDecoration(
                  hintText: widget.hint,
                  prefixIcon: Icon(widget.icon, color: _HealthIntroFlowState.blue),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  filled: true,
                  fillColor: const Color(0xFFF5F7FB),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (_) => _addFromField(),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _addFromField,
              icon: const Icon(Icons.add),
              label: const Text('Add'),
            ),
          ],
        ),
        const SizedBox(height: 12),

        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: widget.common
              .map((c) => _LiquidChip(
                    label: c,
                    selected: widget.selected.contains(c),
                    onTap: () {
                      if (widget.selected.contains(c)) {
                        widget.selected.remove(c);
                      } else {
                        widget.selected.add(c);
                      }
                      widget.onChanged();
                      setState(() {});
                    },
                  ))
              .toList(),
        ),
      ],
    );
  }
}

class _StepAllergyMeds extends StatefulWidget {
  const _StepAllergyMeds({
    required this.allergies,
    required this.meds,
    required this.medPlans,
    required this.onChanged,
  });

  final Set<String> allergies;
  final Set<String> meds;
  final Map<String, Map<String, dynamic>> medPlans; 
  final VoidCallback onChanged;

  @override
  State<_StepAllergyMeds> createState() => _StepAllergyMedsState();
}

class _StepAllergyMedsState extends State<_StepAllergyMeds> {
  final _aCtrl = TextEditingController();
  final _mCtrl = TextEditingController();

  @override
  void dispose() {
    _aCtrl.dispose();
    _mCtrl.dispose();
    super.dispose();
  }

  void _addAllergy() {
    final v = _aCtrl.text.trim();
    if (v.isEmpty) return;
    widget.allergies.add(_titleCase(v));
    _aCtrl.clear();
    widget.onChanged();
    setState(() {});
  }

  void _addMed() {
    final v = _mCtrl.text.trim();
    if (v.isEmpty) return;
    final med = _titleCase(v);
    widget.meds.add(med);
    _mCtrl.clear();

    widget.medPlans.putIfAbsent(med, () => {
      'repeat': 'daily',
      'time': '08:00',
      'weekday': null,
    });

    widget.onChanged();
    setState(() {});
    _openScheduleSheet(med);
  }

  String _titleCase(String s) => s
      .split(' ')
      .where((p) => p.isNotEmpty)
      .map((p) => '${p[0].toUpperCase()}${p.substring(1).toLowerCase()}')
      .join(' ');

  TimeOfDay _parseTime(String hhmm) {
    final parts = hhmm.split(':');
    return TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 8,
      minute: int.tryParse(parts[1]) ?? 0,
    );
  }

  String _planLabel(Map<String, dynamic> p) {
    final rep = (p['repeat'] as String?) ?? 'daily';
    final tod = _parseTime((p['time'] as String?) ?? '08:00');
    final t = tod.format(context);
    if (rep == 'weekly') {
      const d = [null, 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return 'Weekly • ${d[(p['weekday'] as int?) ?? 1]} • $t';
    } else if (rep == 'alternate') {
      return 'Every 2 days • $t';
    }
    return 'Daily • $t';
  }

      Future<void> _openScheduleSheet(String med) async {
        final current = widget.medPlans[med] ?? {
          'repeat': 'daily',
          'time': '08:00',
          'n': 2,
          'days': <int>[DateTime.monday],
        };

        final result = await showModalBottomSheet<Map<String, dynamic>>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (_) => _ScheduleSheet(initial: current),
        );
        if (result == null) return;


        widget.medPlans[med] = result;
        widget.onChanged();
        if (mounted) setState(() {});

        final baseId = med.hashCode & 0x7FFFFFFF;
        await medReminderService.cancelAllFor(baseId);

        final tod = _parseTime(result['time'] as String);
        final title = 'Take $med';
        const body = 'Don’t forget your medication.';
        final repeat = result['repeat'] as String;

        if (repeat == 'daily') {
          await medReminderService.scheduleDaily(
            id: baseId, title: title, body: body, timeOfDay: tod,
          );
        } else if (repeat == 'weekly') {
          final raw = result['days'];
          final days = raw is Set ? raw.cast<int>() : (raw as List).cast<int>();
          await medReminderService.scheduleWeekly(
            baseId: baseId, title: title, body: body, timeOfDay: tod, weekdays: days.toSet(),
          );
        } else if (repeat == 'everyN') {
          final n = (result['n'] as num?)?.toInt() ?? 2;
          await medReminderService.scheduleEveryNDays(
            baseId: baseId, title: title, body: body, timeOfDay: tod, n: n, horizonDays: 180,
          );
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Reminder set: ${_planLabel(result)}')),
        );
      }


  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _H2('Allergies & current meds'),
        const _Sub('Tap to add or select common ones below.'),
        const SizedBox(height: 10),
        const _H3('Allergies'),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: widget.allergies
              .map((s) => _Tag(
                    text: s,
                    onRemove: () {
                      widget.allergies.remove(s);
                      widget.onChanged();
                      setState(() {});
                    },
                  ))
              .toList(),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _aCtrl,
                decoration: _fieldDeco('Type and tap Add…', Icons.vaccines),
                onSubmitted: (_) => _addAllergy(),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _addAllergy,
              icon: const Icon(Icons.add),
              label: const Text('Add'),
            ),
          ],
        ),

        const SizedBox(height: 22),
        const _H3('Medications'),
        const _Sub('Tip: tap “Set schedule” to choose time & frequency.'),
        const SizedBox(height: 8),

        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _mCtrl,
                decoration: _fieldDeco('Type a med and tap Add…', Icons.medication),
                onSubmitted: (_) => _addMed(),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _addMed,
              icon: const Icon(Icons.add),
              label: const Text('Add'),
            ),
          ],
        ),
        const SizedBox(height: 10),

        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: ['Aspirin', 'Metformin', 'Ventolin'].map((c) => _LiquidChip(
            label: c,
            selected: widget.meds.contains(c),
            onTap: () {
              setState(() {
                if (widget.meds.contains(c)) {
                  widget.meds.remove(c);
                } else {
                  widget.meds.add(c);
                  widget.medPlans.putIfAbsent(c, () => {
                    'repeat': 'daily',
                    'time': '08:00',
                    'weekday': null,
                  });
                }
                widget.onChanged();
              });
            },
          )).toList(),
        ),
        const SizedBox(height: 10),

        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: widget.meds.map((med) {
            final plan = widget.medPlans[med];
            return Container(
              padding: const EdgeInsets.only(left: 12, right: 6, top: 6, bottom: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF3F8),
                borderRadius: BorderRadius.circular(999),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    Text(med, style: const TextStyle(
                      fontWeight: FontWeight.w700, color: Color(0xFF334155))),

                    if (plan != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDDE8FF),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.schedule, size: 14, color: Color(0xFF334155)),
                            const SizedBox(width: 4),
                            Text(_planLabel(plan), style: const TextStyle(
                              fontWeight: FontWeight.w700, color: Color(0xFF334155))),
                          ],
                        ),
                      ),

                    TextButton.icon(
                      onPressed: () => _openScheduleSheet(med),
                      icon: const Icon(Icons.notifications_active_outlined),
                      label: const Text('Set schedule'),
                      style: TextButton.styleFrom(
                        foregroundColor: _HealthIntroFlowState.blue,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                      ),
                    ),

                    IconButton(
                      tooltip: 'Remove medication',
                      onPressed: () async {
                        final baseId = med.hashCode & 0x7FFFFFFF;
                        await medReminderService.cancelAllFor(baseId);
                        widget.medPlans.remove(med);
                        widget.meds.remove(med);
                        widget.onChanged();
                        if (mounted) setState(() {});
                      },
                      icon: const Icon(Icons.close, size: 18, color: Color(0xFF64748B)),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(width: 30, height: 30),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  InputDecoration _fieldDeco(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: _HealthIntroFlowState.blue),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      filled: true,
      fillColor: const Color(0xFFF5F7FB),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }
}


class _LiquidChip extends StatefulWidget {
  const _LiquidChip({
    this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData? icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_LiquidChip> createState() => _LiquidChipState();
}

class _LiquidChipState extends State<_LiquidChip> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final sel = widget.selected;
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        scale: _down ? 0.98 : 1.0,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: sel
                ? const LinearGradient(
                    colors: [Color(0xFF3B82F6), Color(0xFF10B981)],
                  )
                : null,
            color: sel ? null : Colors.white,
            border: Border.all(
                color: sel
                    ? Colors.transparent
                    : const Color(0xFFE2E8F0)),
            boxShadow: sel
                ? const [
                    BoxShadow(
                        color: Color(0x223B82F6),
                        blurRadius: 12,
                        offset: Offset(0, 6))
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Icon(widget.icon, size: 18, color: sel ? Colors.white : _HealthIntroFlowState.slate),
                ),
              Text(
                widget.label,
                style: TextStyle(
                  color: sel ? Colors.white : _HealthIntroFlowState.slate,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text, required this.onRemove});
  final String text;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF3F8),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text,
              style: const TextStyle(
                  fontWeight: FontWeight.w700, color: Color(0xFF334155))),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.close, size: 18, color: Color(0xFF64748B)),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 30, height: 30),
          )
        ],
      ),
    );
  }
}

class _H2 extends StatelessWidget {
  const _H2(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(text,
            style: const TextStyle(
                fontSize: 20, fontWeight: FontWeight.w800, color: _HealthIntroFlowState.slate)),
      );
}

class _H3 extends StatelessWidget {
  const _H3(this.text);
  final String text;
  @override
  Widget build(BuildContext context) =>
      Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _HealthIntroFlowState.slate));
}

class _Sub extends StatelessWidget {
  const _Sub(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(text,
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
      );
}

class _PulseBadge extends StatefulWidget {
  const _PulseBadge({required this.child, required this.color});
  final Widget child;
  final Color color;

  @override
  State<_PulseBadge> createState() => _PulseBadgeState();
}

class _PulseBadgeState extends State<_PulseBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
        ..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      height: 140,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) {
          final v = _c.value;
          return CustomPaint(
            painter: _PulsePainter(widget.color, v),
            child: Center(
              child: Container(
                width: 74,
                height: 74,
                decoration: BoxDecoration(
                  color: widget.color,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: widget.color.withValues(alpha: .35),
                        blurRadius: 24,
                        offset: const Offset(0, 12))
                  ],
                ),
                child: Center(child: widget.child),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PulsePainter extends CustomPainter {
  _PulsePainter(this.color, this.t);
  final Color color;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final paint = Paint()..style = PaintingStyle.stroke;
    for (int i = 0; i < 3; i++) {
      final p = ((t + i / 3) % 1.0);
      final r = 40 + 40 * p;
      paint.color = color.withValues(alpha: (1 - p) * .35);
      paint.strokeWidth = 8 * (1 - p);
      canvas.drawCircle(center, r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _PulsePainter oldDelegate) =>
      oldDelegate.t != t || oldDelegate.color != color;
}

class _ScheduleSheet extends StatefulWidget {
  const _ScheduleSheet({required this.initial});
  final Map<String, dynamic> initial;

  @override
  State<_ScheduleSheet> createState() => _ScheduleSheetState();
}

class _ScheduleSheetState extends State<_ScheduleSheet> {
  late String repeat = widget.initial['repeat'] as String? ?? 'daily'; 
  late String time   = widget.initial['time']   as String? ?? '08:00';
  late int n         = (widget.initial['n'] as num?)?.toInt() ?? 2;
  late Set<int> days = () {
    final raw = widget.initial['days'];
    if (raw is Set) return raw.cast<int>();
    if (raw is List) return raw.cast<int>().toSet();
    return <int>{DateTime.monday};
  }();

  String _two(int v) => v.toString().padLeft(2, '0');
  String _fmt(TimeOfDay t) => '${_two(t.hour)}:${_two(t.minute)}';
  TimeOfDay _parse(String hhmm) {
    final p = hhmm.split(':');
    return TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
  }

  @override
  Widget build(BuildContext context) {
    final tod = _parse(time);
    return Padding(
      padding: EdgeInsets.only(
        left: 16, right: 16, top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Medication schedule', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          const SizedBox(height: 12),

          Wrap(spacing: 8, runSpacing: 8, children: [
            ChoiceChip(
              selected: repeat == 'daily',
              label: const Text('Every day'),
              onSelected: (_) => setState(() => repeat = 'daily'),
            ),
            ChoiceChip(
              selected: repeat == 'everyN',
              label: const Text('Every N days'),
              onSelected: (_) => setState(() => repeat = 'everyN'),
            ),
            ChoiceChip(
              selected: repeat == 'weekly',
              label: const Text('Weekly'),
              onSelected: (_) => setState(() => repeat = 'weekly'),
            ),
          ]),

          if (repeat == 'everyN') ...[
            const SizedBox(height: 12),
            Row(
              children: [
                IconButton(
                  onPressed: () => setState(() => n = (n <= 2) ? 2 : n - 1),
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Text('Every $n day${n == 1 ? '' : 's'}',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                IconButton(
                  onPressed: () => setState(() => n = (n >= 30) ? 30 : n + 1),
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
          ],

          if (repeat == 'weekly') ...[
            const SizedBox(height: 12),
            const Text('Days of week', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: [
              _dowChip(DateTime.monday, 'Mon'),
              _dowChip(DateTime.tuesday, 'Tue'),
              _dowChip(DateTime.wednesday, 'Wed'),
              _dowChip(DateTime.thursday, 'Thu'),
              _dowChip(DateTime.friday, 'Fri'),
              _dowChip(DateTime.saturday, 'Sat'),
              _dowChip(DateTime.sunday, 'Sun'),
            ]),
          ],

          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.access_time),
            label: Text('Time • ${tod.format(context)}'),
            onPressed: () async {
              final picked = await showTimePicker(context: context, initialTime: tod);
              if (picked != null) setState(() => time = _fmt(picked));
            },
          ),

          const SizedBox(height: 14),
          ElevatedButton(
            onPressed: () {
              if (repeat == 'weekly' && days.isEmpty) {
                days = {DateTime.monday};
              }
              Navigator.pop<Map<String, dynamic>>(context, {
                'repeat': repeat,
                'time'  : time,
                if (repeat == 'everyN') 'n': n,
                if (repeat == 'weekly') 'days': days.toList(),
              });
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _dowChip(int d, String label) => FilterChip(
    label: Text(label),
    selected: days.contains(d),
    onSelected: (_) => setState(() {
      if (days.contains(d)) {
        days.remove(d);
      } else {
        days.add(d);
      }
    }),
  );
}

