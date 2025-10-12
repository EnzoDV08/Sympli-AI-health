import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:sympli_ai_health/app/features/meds/services/med_reminder_service.dart';
import 'package:sympli_ai_health/app/features/account/widgets/edit_profile_modal.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  late final MedReminderService _medService = MedReminderService(_plugin);

  Map<String, dynamic>? _profile;
  List<Map<String, dynamic>> _reminders = [];
  List<String> _disabilities = [];
  List<String> _allergies = [];
  bool _loading = true;
  int _currentTab = 0;

  @override
  void initState() {
    super.initState();
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
      _disabilities = List<String>.from(data['conditions'] ?? []);
      _allergies = List<String>.from(data['allergies'] ?? []);
      _loading = false;
    });
  }

  Future<void> _removeMedication(String medName) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _medService.cancelAllFor(medName.hashCode & 0x7FFFFFFF);

    final docRef = _firestore.collection('users').doc(uid);
    await _firestore.runTransaction((txn) async {
      final snap = await txn.get(docRef);
      final data = snap.data()?['profile'] ?? {};
      final meds = (data['medicationSchedules'] ?? {}) as Map;
      meds.remove(medName);
      txn.update(docRef, {'profile.medicationSchedules': meds});
    });

    setState(() {
      _reminders.removeWhere((m) => m["name"] == medName);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Removed reminder for $medName")),
    );
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

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF6F8FB),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF37B7A5)),
        ),
      );
    }

    final p = _profile ?? {};

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: const Color(0xFFF6F8FB),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          "Profile",
          style: TextStyle(
              color: Color(0xFF0F172A), fontWeight: FontWeight.w900),
        ),
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
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(top: 120, bottom: 100),
            child: Column(
              children: [
                _buildHeader(p),
                const SizedBox(height: 20),
                _buildBasicStats(p),
                const SizedBox(height: 20),
                _buildHealthSection(),
                const SizedBox(height: 20),
                _buildMedicationSection(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildAccountNavBar(),
    );
  }

  Widget _buildHeader(Map<String, dynamic> p) {
    return Column(
      children: [
        CircleAvatar(
          radius: 55,
          backgroundColor: Colors.white,
          backgroundImage: _auth.currentUser?.photoURL != null
              ? NetworkImage(_auth.currentUser!.photoURL!)
              : const NetworkImage(
                  "https://cdn-icons-png.flaticon.com/512/847/847969.png"),
        ),
        const SizedBox(height: 12),
        Text(
          p['name'] ?? _auth.currentUser?.displayName ?? 'User',
          style: const TextStyle(
              fontSize: 24, fontWeight: FontWeight.w900, color: Colors.black87),
        ),
        const SizedBox(height: 4),
        Text(
          "${p['gender'] ?? 'N/A'} • ${p['age'] ?? '--'} yrs",
          style: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
        ),
      ],
    ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.2);
  }

  Widget _buildBasicStats(Map<String, dynamic> p) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.7),
              borderRadius: BorderRadius.circular(22),
              boxShadow: const [
                BoxShadow(
                    color: Color(0x22000000),
                    blurRadius: 18,
                    offset: Offset(0, 6))
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _infoTile(Icons.bloodtype, p['bloodType'] ?? "N/A", "Blood Type"),
                _infoTile(Icons.wc, p['gender'] ?? "N/A", "Gender"),
                _infoTile(Icons.calendar_today,
                    "${p['age'] ?? '--'}", "Age"),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHealthSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.65),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Health Information",
                    style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        color: Color(0xFF0F172A))),
                const SizedBox(height: 10),
                _infoRow("Disabilities",
                    _disabilities.isEmpty ? "None" : _disabilities.join(', ')),
                _infoRow("Allergies",
                    _allergies.isEmpty ? "None" : _allergies.join(', ')),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMedicationSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.7),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.medication_liquid_rounded,
                        color: Color(0xFF3B82F6)),
                    SizedBox(width: 10),
                    Text(
                      "Medication Reminders",
                      style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          color: Color(0xFF0F172A)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_reminders.isEmpty)
                  const Text("No medication reminders yet.",
                      style: TextStyle(color: Color(0xFF64748B)))
                else
                  Column(
                    children: _reminders
                        .map(
                          (r) => ListTile(
                            leading: const Icon(Icons.alarm_rounded,
                                color: Color(0xFF3B82F6)),
                            title: Text(
                              r["name"],
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            subtitle: Text(
                              "${r["repeat"]} • ${r["time"]}",
                              style: const TextStyle(
                                  color: Color(0xFF64748B), fontSize: 13),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: Colors.redAccent),
                              onPressed: () => _removeMedication(r["name"]),
                            ),
                          ).animate().fadeIn(duration: 400.ms),
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

  Widget _infoTile(IconData icon, String value, String label) {
    return Column(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: const Color(0xFF37B7A5).withOpacity(0.1),
          child: Icon(icon, color: const Color(0xFF37B7A5)),
        ),
        const SizedBox(height: 8),
        Text(value,
            style: const TextStyle(
                fontWeight: FontWeight.w900, color: Color(0xFF0F172A))),
        Text(label,
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: const Color(0xFF3B82F6)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "$label: $value",
              style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontWeight: FontWeight.w600,
                  fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountNavBar() {
    final items = [
      {"icon": Icons.person_rounded, "label": "Profile"},
      {"icon": Icons.chat_bubble_outline_rounded, "label": "Past Chats"},
      {"icon": Icons.settings_rounded, "label": "Settings"},
    ];

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: BottomNavigationBar(
          currentIndex: _currentTab,
          onTap: (i) {
            setState(() => _currentTab = i);
            // TODO: Implement routing if needed
          },
          backgroundColor: Colors.white.withOpacity(0.8),
          selectedItemColor: const Color(0xFF37B7A5),
          unselectedItemColor: const Color(0xFF94A3B8),
          items: items
              .map(
                (item) => BottomNavigationBarItem(
                  icon: Icon(item["icon"] as IconData),
                  label: item["label"] as String,
                ),
              )
              .toList(),
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
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 10))
      ..repeat(reverse: true);
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
