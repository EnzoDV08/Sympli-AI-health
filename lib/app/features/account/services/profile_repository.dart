import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sympli_ai_health/app/utils/logging.dart' as log;
import 'package:sympli_ai_health/app/features/meds/services/med_reminder_service.dart';

class SympliUser {
  final String uid;
  final String? username;
  final String? email;
  final bool? onboardingComplete;
  final Map<String, dynamic>? profile;
  final List<dynamic>? medications;
  final String? profileImage;

  SympliUser({
    required this.uid,
    this.username,
    this.email,
    this.onboardingComplete,
    this.profile,
    this.medications,
    this.profileImage,
  });

  factory SympliUser.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return SympliUser(
      uid: doc.id,
      username: d['username'] as String?,
      email: d['email'] as String?,
      onboardingComplete: d['onboardingComplete'] as bool?,
      profile: d['profile'] as Map<String, dynamic>?,
      medications: (d['medications'] as List?) ?? const [],
      profileImage: d['profileImage'] as String?, 
    );
  }
}

class MedicationReminder {
  final String id;
  final String name;
  final String? dosage;
  final String? instructions;
  final String? repeat;
  final String? time;
  final String? timezone;
  final bool active;

  MedicationReminder({
    required this.id,
    required this.name,
    this.dosage,
    this.instructions,
    this.repeat,
    this.time,
    this.timezone,
    required this.active,
  });

  factory MedicationReminder.fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    final plan = d['plan'] ?? {};
    return MedicationReminder(
      id: doc.id,
      name: d['name'] ?? 'Unnamed',
      dosage: d['dosage'],
      instructions: d['instructions'],
      repeat: plan['repeat'] ?? d['repeat'],
      time: plan['time'] ?? d['time'],
      timezone: plan['timezone'] ?? d['timezone'],
      active: d['active'] ?? false,
    );
  }
}

class ProfileRepository {
  final _firestore = FirebaseFirestore.instance;

  Stream<SympliUser?> userStream(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((snap) => snap.exists ? SympliUser.fromDoc(snap) : null);
  }

  Stream<List<MedicationReminder>> remindersStream(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('medication_reminders')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map(MedicationReminder.fromDoc).toList());
  }

  Future<void> updateTime(String uid, String reminderId,
      {required String hhmm}) async {
    final docRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('medication_reminders')
        .doc(reminderId);

    await docRef.update({'plan.time': hhmm, 'time': hhmm});
    log.logI('⏰ Updated reminder $reminderId time → $hhmm');
  }

  Future<void> createReminderManual({
    required String uid,
    required String name,
    String? dosage,
    String? instructions,
    String repeat = 'daily',
    required String timeHHmm,
    String timezone = 'SAST',
    bool active = true,
  }) async {
    final normalizedName = name.trim();
    final ref = _firestore
        .collection('users')
        .doc(uid)
        .collection('medication_reminders')
        .doc('med_${normalizedName.toLowerCase()}');

    final reminderData = {
      'active': active,
      'name': normalizedName,
      if (dosage != null) 'dosage': dosage,
      if (instructions != null) 'instructions': instructions,
      'createdAt': FieldValue.serverTimestamp(),
      'plan': {
        'repeat': repeat,
        'time': timeHHmm,
        'timezone': timezone,
      },
      'userId': uid,
      'reminderId': ref.id,
    };

    await ref.set(reminderData);

    await _firestore.collection('users').doc(uid).set({
      'medications': FieldValue.arrayUnion([normalizedName]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    log.logI('✅ Created reminder + added "$normalizedName" to medications');
  }

  Future<void> updateReminder(
      String uid, String reminderId, Map<String, dynamic> data) async {
    final docRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('medication_reminders')
        .doc(reminderId);

    await docRef.update(data);

    final snap = await docRef.get();
    if (snap.exists) {
      final reminder = snap.data()!;
      final medName = (reminder['name'] ?? '').toString().trim();
      await _firestore.collection('users').doc(uid).set({
        'medications': FieldValue.arrayUnion([medName]),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      log.logI('🔁 Updated reminder for "$medName"');
    }
  }

  Future<void> deleteReminder(String uid, String reminderId) async {
    final docRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('medication_reminders')
        .doc(reminderId);

    final snap = await docRef.get();
    final medName = (snap.data()?['name'] ?? '').toString().trim();

    await docRef.delete();

    if (medName.isNotEmpty) {
      await _firestore.collection('users').doc(uid).update({
        'medications': FieldValue.arrayRemove([medName]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      log.logI('🗑️ Deleted "$medName" reminder and removed from medications');
    }
  }

Future<void> setActive(String uid, String reminderId, bool active) async {
  final reminderRef = _firestore
      .collection('users')
      .doc(uid)
      .collection('medication_reminders')
      .doc(reminderId);

  await reminderRef.update({'active': active});
  log.logI('✅ Reminder $reminderId → Active: $active');

  try {
    final snap = await reminderRef.get();
    if (!snap.exists) return;
    final data = snap.data()!;
    final name = data['name'] ?? '';
    final baseId = reminderId.hashCode & 0x7FFFFFFF;

    if (!active) {
      await medReminderService.cancelAllFor(baseId);
      log.logI('🧹 Canceled local notifications for "$name" (set inactive)');
    } else {
      final plan = data['plan'] as Map?;
      if (plan != null) {
        await medReminderService.scheduleLocalNotification(
          uid: uid,
          name: name,
          dosage: data['dosage'],
          instructions: data['instructions'],
          repeat: plan['repeat'] ?? 'daily',
          time: plan['time'] ?? '08:00',
          timezone: plan['timezone'] ?? 'SAST',
          days: (plan['days'] as List?)?.map((e) => e as int).toList(),
          n: plan['n'],
          hours: plan['hours'],
        );
        log.logI('🔁 Re-scheduled "$name" (set active again)');
      }
    }
  } catch (e, st) {
    log.logE('⚠️ Error toggling reminder active state', e, st);
  }
}
}

extension ProfileImageRepo on ProfileRepository {
  FirebaseStorage get _storage => FirebaseStorage.instance;
  FirebaseAuth get _auth => FirebaseAuth.instance;

  Future<String?> uploadProfileImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return null;

    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;

    final file = File(picked.path);
    final ref = _storage.ref().child('profile_images/$uid.jpg');

    final uploadTask = await ref.putFile(file);
    final url = await uploadTask.ref.getDownloadURL();

    await _firestore.collection('users').doc(uid).set({
      'profileImage': url,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    log.logI('📸 Uploaded new profile image for user $uid');
    return url;
  }

  Future<void> removeProfileImage() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    try {
      final ref = _storage.ref().child('profile_images/$uid.jpg');
      await ref.delete();

      await _firestore.collection('users').doc(uid).set({
        'profileImage': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      log.logI('🧹 Removed profile image for user $uid');
    } catch (e, st) {
      log.logE('⚠️ Error removing profile image', e, st);
    }
  }
}
