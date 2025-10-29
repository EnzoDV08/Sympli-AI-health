import 'dart:io';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class EditProfileModal extends StatefulWidget {
  const EditProfileModal({super.key});

  @override
  State<EditProfileModal> createState() => _EditProfileModalState();
}

class _EditProfileModalState extends State<EditProfileModal> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  final _nameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();

  String? _originalName;
  bool _isNameEditing = false;

  String? _gender;
  final Set<String> _conditions = {};
  String? _profileImageUrl;

  bool _saving = false;
  bool _uploading = false;

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

    setState(() {
_nameCtrl.text =
    (doc.data()?['username'] ?? _auth.currentUser?.displayName ?? '').toString();
      _ageCtrl.text = (data['age']?.toString() ?? '');
      _gender = data['gender'];
      _conditions.addAll(List<String>.from(data['conditions'] ?? []));
      _profileImageUrl = doc.data()?['profileImage'];
      _originalName = _nameCtrl.text;
    });
  }

    Future<void> _pickProfileImage() async {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: ImageSource.gallery);
      if (picked == null) return;

      setState(() => _uploading = true);
      final uid = _auth.currentUser?.uid;
      if (uid == null) return;

      final file = File(picked.path);

      final ref = _storage.ref().child('profile_images/$uid/profile.jpg');

      // Upload file
      await ref.putFile(file);

      final url = await ref.getDownloadURL();

      await _firestore.collection('users').doc(uid).set({
        'profileImage': url,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      setState(() {
        _uploading = false;
        _profileImageUrl = url;
      });
    }


Future<void> _removeProfileImage() async {
  final uid = _auth.currentUser?.uid;
  if (uid == null) return;

  setState(() => _uploading = true); 

  try {
    final ref = _storage.ref().child('profile_images/$uid/profile.jpg');
    await ref.delete();
  } catch (_) {}

  await _firestore.collection('users').doc(uid).set({
    'profileImage': FieldValue.delete(),
    'updatedAt': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));

  await Future.delayed(const Duration(milliseconds: 800));

  setState(() {
    _profileImageUrl = null;
    _uploading = false; 
  });

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('🗑️ Profile image removed successfully'),
      backgroundColor: Colors.redAccent,
    ),
  );
}



Future<void> _save() async {
  final uid = _auth.currentUser?.uid;
  if (uid == null || _saving) return;

  setState(() => _saving = true);

  try {
    await _firestore.collection('users').doc(uid).set({
      'username': _nameCtrl.text.trim(), 
      'profile': {
        'age': int.tryParse(_ageCtrl.text.trim()) ?? 0,
        'gender': _gender,
        'conditions': _conditions.toList(),
      },
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));


    await _auth.currentUser?.updateDisplayName(_nameCtrl.text.trim());

    if (mounted) {
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('✅ Profile updated successfully'),
        backgroundColor: Color(0xFF3B82F6),
      ));
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('⚠️ Failed to update profile: $e')),
    );
  } finally {
    if (mounted) setState(() => _saving = false);
  }
}


  void _addCondition() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white.withValues(alpha: 0.9),
        title: const Text("Add Condition"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: "e.g., Diabetes"),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
            ),
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty) {
                setState(() => _conditions.add(_capitalize(text)));
              }
              Navigator.pop(ctx);
            },
            child: const Text("Add", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          color: Colors.white.withValues(alpha: 0.9),
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 100,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 60,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const Center(
                  child: Text(
                    "Edit Profile",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                
                Column(
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        CircleAvatar(
                          radius: 45,
                          backgroundColor: const Color(0xFF37B7A5),
                          backgroundImage: _profileImageUrl != null
                              ? NetworkImage(_profileImageUrl!)
                              : null,
                          child: _profileImageUrl == null
                              ? const Icon(Icons.person, color: Colors.white, size: 45)
                              : null,
                        ),
                        if (_uploading)
                          const Positioned.fill(
                            child: Center(
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            ),
                          ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: InkWell(
                            onTap: _pickProfileImage,
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Color(0xFF37B7A5),
                                shape: BoxShape.circle,
                              ),
                              padding: const EdgeInsets.all(6),
                              child: const Icon(Icons.edit, color: Colors.white, size: 20),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    if (_profileImageUrl != null)
                      TextButton.icon(
                        onPressed: _removeProfileImage,
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                        label: const Text(
                          "Remove Profile Image",
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),



                const SizedBox(height: 24),
                if (_nameCtrl.text.isNotEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      _nameCtrl.text,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Focus(
                  onFocusChange: (focused) {
                    if (!focused) {
                      if (_nameCtrl.text.trim().isEmpty || _nameCtrl.text == _originalName) {
                        setState(() {
                          _nameCtrl.text = _originalName ?? '';
                          _isNameEditing = false;
                        });
                      }
                    } else {
                      setState(() => _isNameEditing = true);
                    }
                  },
                  child: TextField(
                    controller: _nameCtrl,
                    onChanged: (value) => setState(() {}), 
                    decoration: InputDecoration(
                      labelText: "Username",
                      hintText: _isNameEditing ? "Enter your username" : _nameCtrl.text,
                      prefixIcon: const Icon(Icons.person_rounded, color: Color(0xFF3B82F6)),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              ),
                _inputField(
                  label: "Age",
                  controller: _ageCtrl,
                  icon: Icons.cake_rounded,
                  hint: "Enter your age",
                  type: TextInputType.number,
                ),
                _dropdownField(
                  label: "Gender",
                  icon: Icons.wc_rounded,
                  value: _gender,
                  items: const ["Male", "Female", "Other"],
                  onChanged: (v) => setState(() => _gender = v),
                ),
                const SizedBox(height: 18),
                const Text("Conditions",
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                        fontSize: 16)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _conditions.map((c) {
                    return Chip(
                      label: Text(c),
                      backgroundColor: const Color(0xFFEEF2FF),
                      deleteIcon: const Icon(Icons.close, size: 16),
                      onDeleted: () {
                        setState(() => _conditions.remove(c));
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),
                Center(
                  child: OutlinedButton.icon(
                    onPressed: _addCondition,
                    icon: const Icon(Icons.add, color: Color(0xFF3B82F6)),
                    label: const Text("Add Condition",
                        style: TextStyle(color: Color(0xFF3B82F6))),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF3B82F6)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30)),
                    ),
                  ),
                ),
                const SizedBox(height: 30),

                Center(
                  child: ElevatedButton.icon(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B82F6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                    ),
                    icon: _saving
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.save, color: Colors.white),
                    label: const Text(
                      "Save Changes",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),

                const SizedBox(height: 16),


              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _inputField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    TextInputType type = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        keyboardType: type,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon, color: const Color(0xFF3B82F6)),
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _dropdownField({
    required String label,
    required IconData icon,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: const Color(0xFF3B82F6)),
          filled: true,
          fillColor: const Color(0xFFF8FAFC),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: value,
            hint: const Text("Select"),
            isExpanded: true,
            items: items
                .map((e) => DropdownMenuItem(
                      value: e,
                      child: Text(e),
                    ))
                .toList(),
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }
}
