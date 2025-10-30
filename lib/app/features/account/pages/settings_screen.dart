import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sympli_ai_health/app/features/account/services/app_settings.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sympli_ai_health/app/features/meds/services/med_reminder_service.dart';



class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final notifier = ref.read(appSettingsProvider.notifier);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 100),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: settings.darkModeEnabled
                    ? Colors.black.withOpacity(0.4)
                    : Colors.white.withOpacity(0.35),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withOpacity(0.4), width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1CB5E0).withOpacity(0.15),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Settings",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 20),

                  _settingToggle(
                    icon: Icons.notifications_active_rounded,
                    title: "Notifications",
                    subtitle: "Manage reminders",
                    value: settings.notificationsEnabled,
                    onChanged: (v) => notifier.toggleNotifications(v),
                    gradientColors: const [Color(0xFF37B7A5), Color(0xFF1CB5E0)],
                  ),

                  _settingToggle(
                    icon: Icons.color_lens_rounded,
                    title: "Theme",
                    subtitle: settings.darkModeEnabled ? "Dark Mode" : "Light Mode",
                    value: settings.darkModeEnabled,
                    onChanged: (v) => notifier.toggleTheme(v),
                    gradientColors: const [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                  ),

                  _settingStatic(
                    icon: Icons.lock_outline_rounded,
                    title: "Privacy Policy",
                    subtitle: "Terms & security info",
                    gradientColors: const [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
                  ),

                  const SizedBox(height: 40),

                  Center(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        try {
                          await FirebaseAuth.instance.signOut();
                          if (context.mounted) {
                            context.go('/onboarding');
                          }
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error signing out: $e'),
                              backgroundColor: Colors.redAccent,
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.logout, color: Colors.white),
                      label: const Text(
                        "Log Out",
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEF4444),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 42, vertical: 16),
                        elevation: 3,
                        shadowColor: Colors.redAccent.withOpacity(0.4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final user = FirebaseAuth.instance.currentUser;

                        if (user == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("No user is currently signed in."),
                              backgroundColor: Colors.redAccent,
                            ),
                          );
                          return;
                        }

                        final isEmailUser = user.providerData.any((p) => p.providerId == 'password');

                        final confirmed = await showDialog<bool>(
                          context: context,
                          barrierDismissible: false,
                          builder: (context) {
                            final TextEditingController passwordController = TextEditingController();
                            bool isDeleting = false;

                            return StatefulBuilder(
                              builder: (context, setState) => AlertDialog(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                title: const Text(
                                  "Delete Account?",
                                  style: TextStyle(fontWeight: FontWeight.w800),
                                ),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Text(
                                      "This will permanently delete your account and all data.",
                                      style: TextStyle(fontSize: 14, color: Color(0xFF475569)),
                                    ),
                                    if (isEmailUser) ...[
                                      const SizedBox(height: 16),
                                      const Text(
                                        "Please confirm by entering your password below.",
                                        style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                                      ),
                                      const SizedBox(height: 8),
                                      TextField(
                                        controller: passwordController,
                                        obscureText: true,
                                        decoration: const InputDecoration(
                                          hintText: "Enter your password",
                                          prefixIcon: Icon(Icons.lock_outline),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.all(Radius.circular(12)),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, false),
                                    child: const Text("Cancel"),
                                  ),
                                  ElevatedButton(
                                  onPressed: isDeleting
                                      ? null
                                      : () async {
                                          setState(() => isDeleting = true);
                                          try {
                                            final user = FirebaseAuth.instance.currentUser;
                                            if (user == null) throw Exception("No user signed in");
                                            final isEmailUser =
                                                user.providerData.any((p) => p.providerId == 'password');

                                            if (isEmailUser) {
                                              final cred = EmailAuthProvider.credential(
                                                email: user.email ?? '',
                                                password: passwordController.text.trim(),
                                              );
                                              await user.reauthenticateWithCredential(cred);
                                            } else {
                                              final googleSignIn = GoogleSignIn();
                                              final googleUser = await googleSignIn.signInSilently();
                                              if (googleUser != null) {
                                                final googleAuth = await googleUser.authentication;
                                                final credential = GoogleAuthProvider.credential(
                                                  accessToken: googleAuth.accessToken,
                                                  idToken: googleAuth.idToken,
                                                );
                                                await user.reauthenticateWithCredential(credential);
                                              } else {
                                                await user.reauthenticateWithProvider(GoogleAuthProvider());
                                              }
                                            }

                                            final uid = user.uid;
                                            final userDoc =
                                                FirebaseFirestore.instance.collection('users').doc(uid);
                                            final usernamesRef =
                                                FirebaseFirestore.instance.collection('usernames');

                                            await notificationsPlugin.cancelAll();

                                            final subcollections = [
                                              'medication_reminders',
                                              'chats',
                                              'logs',
                                              'reminders'
                                            ];

                                            for (final sub in subcollections) {
                                              final snapshot = await userDoc.collection(sub).get();
                                              for (final doc in snapshot.docs) {
                                                await doc.reference.delete();
                                              }
                                              debugPrint('✅ Deleted subcollection: $sub');
                                            }

                                            final usernameSnap =
                                                await usernamesRef.where('uid', isEqualTo: uid).get();
                                            for (final doc in usernameSnap.docs) {
                                              await doc.reference.delete();
                                              debugPrint('✅ Deleted username document: ${doc.id}');
                                            }

                                            await userDoc.delete();
                                            debugPrint('✅ Deleted main user document');

                                            await user.delete();
                                            debugPrint('✅ Firebase Auth user deleted');

                                            await FirebaseAuth.instance.signOut();
                                            await GoogleSignIn().signOut();
                                            await FirebaseFirestore.instance.terminate();
                                            await FirebaseFirestore.instance.clearPersistence();

                                            if (context.mounted) {
                                              final rootContext =
                                                  Navigator.of(context, rootNavigator: true).context;
                                              Future.microtask(() {
                                                ScaffoldMessenger.of(rootContext).showSnackBar(
                                                  const SnackBar(
                                                    content:
                                                        Text("✅ Your account and all data were deleted permanently."),
                                                    backgroundColor: Colors.redAccent,
                                                  ),
                                                );
                                                rootContext.go('/onboarding');
                                              });
                                            }
                                          } catch (e) {
                                            debugPrint('❌ Error deleting account: $e');
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text('Error deleting account: $e'),
                                                backgroundColor: Colors.redAccent,
                                              ),
                                            );
                                            setState(() => isDeleting = false);
                                          }
                                        },

                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    child: isDeleting
                                        ? const SizedBox(
                                            height: 18,
                                            width: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                            ),
                                          )
                                        : const Text("Delete"),
                                  ),
                                ],
                              ),
                            );
                          },
                        );

                        if (confirmed == true) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Account permanently deleted."),
                                backgroundColor: Colors.redAccent,
                              ),
                            );
                            context.go('/onboarding');
                          }
                        }
                      },
                      icon: const Icon(Icons.delete_forever_rounded, color: Colors.white),
                      label: const Text(
                        "Delete Account",
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black.withOpacity(0.85),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 42, vertical: 16),
                        elevation: 3,
                        shadowColor: Colors.black26,
                      ),
                    ),
                  ),


                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _settingToggle({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
    required List<Color> gradientColors,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: gradientColors),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                    fontSize: 15,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF475569),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: gradientColors.first,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: Colors.grey.shade300,
          ),
        ],
      ),
    );
  }

  Widget _settingStatic({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Color> gradientColors,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: gradientColors),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                    fontSize: 15,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF475569),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios_rounded,
              size: 14, color: Color(0xFF6366F1)),
        ],
      ),
    );
  }
}
