import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:sympli_ai_health/app/features/meds/services/med_reminder_service.dart';
import 'package:sympli_ai_health/app/features/account/widgets/edit_profile_modal.dart';
import 'package:sympli_ai_health/app/features/account/pages/chat_history_screen.dart';
import 'package:sympli_ai_health/app/features/account/pages/settings_screen.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen>
    with SingleTickerProviderStateMixin {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  late final MedReminderService _medService = MedReminderService(_plugin);

  Map<String, dynamic>? _profile;
  bool _loading = true;
  List<Map<String, dynamic>> _reminders = [];

  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final doc = await _firestore.collection('users').doc(uid).get();
    final data = doc.data()?['profile'] ?? {};
    final meds = (data['medicationSchedules'] ?? {}) as Map;

    setState(() {
      _profile = data;
      _reminders = meds.entries
          .map((e) => {
                "name": e.key,
                "time": e.value['time'],
                "repeat": e.value['repeat']
              })
          .toList();
      _loading = false;
    });
  }

  Future<void> _openEditModal() async {
    final updated = await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const EditProfileModal(),
    );
    if (updated == true) _loadProfile();
  }

  Future<void> _addMedication() async {
    final nameCtrl = TextEditingController();
    TimeOfDay? selectedTime;
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 24,
          bottom: MediaQuery.of(context).viewInsets.bottom + 30,
        ),
        child: StatefulBuilder(
          builder: (ctx, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Add Medication Reminder",
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
              const SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: "Medication Name",
                  prefixIcon: Icon(Icons.medication_rounded),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                icon: const Icon(Icons.access_time),
                label: Text(selectedTime == null
                    ? "Pick Reminder Time"
                    : selectedTime!.format(context)),
                onPressed: () async {
                  final t = await showTimePicker(
                      context: ctx, initialTime: TimeOfDay.now());
                  if (t != null) setState(() => selectedTime = t);
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () async {
                  if (nameCtrl.text.trim().isEmpty || selectedTime == null) return;
                  await _medService.scheduleDaily(
                    id: DateTime.now().millisecondsSinceEpoch % 100000,
                    title: "Take ${nameCtrl.text.trim()}",
                    body: "Time to take your medication.",
                    timeOfDay: selectedTime!,
                  );
                  if (mounted) Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text("Medication reminder added"),
                      backgroundColor: Color(0xFF3B82F6)));
                },
                icon: const Icon(Icons.check, color: Colors.white),
                label: const Text("Save", style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final p = _profile ?? {};
    final paddingBottom = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: const Color(0xFFF6F8FB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text("Account",
            style: TextStyle(
                fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded, color: Color(0xFF334155)),
            onPressed: _openEditModal,
          ),
        ],
      ),
      body: Stack(
        children: [
          _AnimatedGradientBackground(),

          /// Main Account Navigation (Profile | Chats | Settings)
          Column(
            children: [
              const SizedBox(height: 110), // shifts everything above navbar

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: TabBar(
                        controller: _tabCtrl,
                        indicatorColor: const Color(0xFF37B7A5),
                        labelColor: const Color(0xFF37B7A5),
                        unselectedLabelColor: const Color(0xFF64748B),
                        indicatorWeight: 3,
                        labelStyle: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14),
                        tabs: const [
                          Tab(
                              icon: Icon(Icons.person_rounded),
                              text: "Profile"),
                          Tab(
                              icon: Icon(Icons.chat_bubble_outline_rounded),
                              text: "Chats"),
                          Tab(
                              icon: Icon(Icons.settings_rounded),
                              text: "Settings"),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              /// Tab Content
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: paddingBottom + 70),
                  child: TabBarView(
                    controller: _tabCtrl,
                    children: [
                      _buildProfileTab(p),
                      const ChatHistoryScreen(),
                      const SettingsScreen(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfileTab(Map<String, dynamic> p) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        children: [
          _buildProfileHeader(p).animate().fadeIn(duration: 500.ms),
          const SizedBox(height: 20),
          _buildInfoSection(p).animate().fadeIn(duration: 600.ms),
          const SizedBox(height: 24),
          _buildMedsSection().animate().fadeIn(duration: 700.ms),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(Map<String, dynamic> p) {
    return Center(
      child: Column(
        children: [
          CircleAvatar(
            radius: 55,
            backgroundColor: Colors.white,
            backgroundImage: _auth.currentUser?.photoURL != null
                ? NetworkImage(_auth.currentUser!.photoURL!)
                : const NetworkImage(
                    "https://cdn-icons-png.flaticon.com/512/847/847969.png"),
          ),
          const SizedBox(height: 14),
          Text(
            p['name'] ?? _auth.currentUser?.displayName ?? 'User',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Blood Type: ${p['bloodType'] ?? 'N/A'}",
            style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(Map<String, dynamic> p) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.65),
              border: Border.all(color: Colors.white.withOpacity(0.5)),
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x22000000),
                    blurRadius: 18,
                    offset: Offset(0, 8))
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Personal Info",
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF0F172A))),
                const SizedBox(height: 12),
                _infoTile(Icons.person_outline, "Gender", p['gender'] ?? "N/A"),
                _infoTile(Icons.cake_outlined, "Age",
                    "${p['age'] ?? '--'} years old"),
                _infoTile(Icons.favorite_outline, "Conditions",
                    (p['conditions']?.join(', ') ?? 'None')),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoTile(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF3B82F6)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14)),
                Text(value,
                    style: const TextStyle(
                        color: Color(0xFF64748B), fontSize: 13)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildMedsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.65),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.medication_rounded,
                        color: Color(0xFF3B82F6)),
                    const SizedBox(width: 8),
                    const Text("Medication Reminders",
                        style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            color: Color(0xFF0F172A))),
                    const Spacer(),
                    IconButton(
                        onPressed: _addMedication,
                        icon: const Icon(Icons.add_circle_outline,
                            color: Color(0xFF3B82F6))),
                  ],
                ),
                const SizedBox(height: 10),
                if (_reminders.isEmpty)
                  const Text("No reminders yet.",
                      style: TextStyle(color: Color(0xFF64748B)))
                else
                  Column(
                    children: _reminders
                        .map(
                          (r) => ListTile(
                            leading: const Icon(Icons.alarm_rounded,
                                color: Color(0xFF3B82F6)),
                            title: Text(r["name"],
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                            subtitle: Text(
                                "${r["repeat"]} • ${r["time"]}",
                                style: const TextStyle(
                                    color: Color(0xFF64748B))),
                          ).animate().slideY(begin: 0.2, duration: 400.ms),
                        )
                        .toList(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedGradientBackground extends StatefulWidget {
  @override
  State<_AnimatedGradientBackground> createState() =>
      _AnimatedGradientBackgroundState();
}

class _AnimatedGradientBackgroundState
    extends State<_AnimatedGradientBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(const Color(0xFFA5F0E6), const Color(0xFFB9E9FF), t)!,
                Color.lerp(const Color(0xFFB9E9FF), const Color(0xFFA5F0E6), t)!,
              ],
            ),
          ),
        );
      },
    );
  }
}
