import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

class EditProfileScreen extends StatefulWidget {
  // ── Constructor made no-arg so it can be pushed without pre-fetching data.
  // The screen loads its own data from Firestore via the current user.
  // Old callers that passed name/email/imagePath will still compile because
  // those params are kept as optional for backwards compatibility.
  const EditProfileScreen({
    super.key,
    // kept for backwards compat — ignored internally (we read from Firestore)
    @Deprecated('Data is loaded from Firestore automatically') String? name,
    @Deprecated('Data is loaded from Firestore automatically') String? email,
    @Deprecated('Data is loaded from Firestore automatically')
    String? imagePath,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  // ── Controllers ────────────────────────────────────────────────────────────
  final _nameCtrl = TextEditingController();

  // ── State ──────────────────────────────────────────────────────────────────
  File?   _pickedImage;        // newly selected local file
  String? _existingPhotoUrl;  // current Firebase Storage URL
  String  _selectedBranch = 'CSE';
  bool    _isSaving        = false;
  bool    _isLoading       = true;
  String  _email           = '';

  // ── Branch options (matches CollegeOnboardingScreen) ──────────────────────
  static const List<String> _branches = [
    'CSE', 'ECE', 'ME', 'CE', 'EE', 'IT', 'BT', 'Other',
  ];

  // ── Upload progress (shown while uploading image) ─────────────────────────
  double? _uploadProgress;

  @override
  void initState() {
    super.initState();
    _loadCurrentProfile();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  // ── Load existing profile data ─────────────────────────────────────────────
  Future<void> _loadCurrentProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!mounted) return;

      final data = snap.data() ?? {};
      setState(() {
        _nameCtrl.text     = data['name']       ?? user.displayName ?? '';
        _email             = data['email']       ?? user.email       ?? '';
        _selectedBranch    = data['branch']      ?? 'CSE';
        _existingPhotoUrl  = data['photoUrl']    as String?;
        _isLoading         = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Image picking ──────────────────────────────────────────────────────────
  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF203A43),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              const Text(
                'Update Profile Photo',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),

              const SizedBox(height: 12),

              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.teal.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.photo_library_outlined,
                      color: Colors.tealAccent),
                ),
                title: const Text('Choose from Gallery',
                    style: TextStyle(color: Colors.white)),
                subtitle: const Text('JPG, PNG supported',
                    style: TextStyle(color: Colors.white54, fontSize: 12)),
                onTap: () {
                  Navigator.pop(context);
                  _pickFromGallery();
                },
              ),

              if (Platform.isAndroid || Platform.isIOS)
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.camera_alt_outlined,
                        color: Colors.blueAccent),
                  ),
                  title: const Text('Take a Photo',
                      style: TextStyle(color: Colors.white)),
                  subtitle: const Text('Use your camera',
                      style: TextStyle(color: Colors.white54, fontSize: 12)),
                  onTap: () {
                    Navigator.pop(context);
                    _pickFromCamera();
                  },
                ),

              if (_existingPhotoUrl != null || _pickedImage != null)
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.delete_outline,
                        color: Colors.redAccent),
                  ),
                  title: const Text('Remove Photo',
                      style: TextStyle(color: Colors.redAccent)),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _pickedImage      = null;
                      _existingPhotoUrl = null;
                    });
                  },
                ),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickFromGallery() async {
    final image = await ImagePicker().pickImage(
      source:       ImageSource.gallery,
      imageQuality: 75,
      maxWidth:     800,
      maxHeight:    800,
    );
    if (image != null && mounted) {
      setState(() => _pickedImage = File(image.path));
    }
  }

  Future<void> _pickFromCamera() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      _snack('Camera permission denied');
      return;
    }

    final image = await ImagePicker().pickImage(
      source:       ImageSource.camera,
      imageQuality: 75,
      maxWidth:     800,
      maxHeight:    800,
    );
    if (image != null && mounted) {
      setState(() => _pickedImage = File(image.path));
    }
  }

  // ── Upload image to Firebase Storage ──────────────────────────────────────
  Future<String?> _uploadImage(String uid) async {
    if (_pickedImage == null) return _existingPhotoUrl;

    setState(() => _uploadProgress = 0);

    try {
      final ref = FirebaseStorage.instance
          .ref()
          .child('profile_photos')
          .child('$uid.jpg');

      final task = ref.putFile(
        _pickedImage!,
        SettableMetadata(contentType: 'image/jpeg'),
      );

      // Track upload progress
      task.snapshotEvents.listen((snap) {
        if (!mounted) return;
        final progress =
            snap.bytesTransferred / (snap.totalBytes == 0 ? 1 : snap.totalBytes);
        setState(() => _uploadProgress = progress);
      });

      await task;
      final url = await ref.getDownloadURL();
      if (mounted) setState(() => _uploadProgress = null);
      return url;
    } catch (e) {
      if (mounted) setState(() => _uploadProgress = null);
      _snack('Image upload failed — profile saved without photo');
      return _existingPhotoUrl; // fall back to existing URL
    }
  }

  // ── Save profile ───────────────────────────────────────────────────────────
  Future<void> _saveProfile() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      _snack('Name cannot be empty');
      return;
    }
    if (name.length < 2) {
      _snack('Name must be at least 2 characters');
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isSaving = true);

    try {
      // 1. Upload photo if a new one was picked
      final photoUrl = await _uploadImage(user.uid);

      // 2. Update Firestore
      final updates = <String, dynamic>{
        'name':      name,
        'branch':    _selectedBranch,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (photoUrl != null)       updates['photoUrl']  = photoUrl;
      if (_existingPhotoUrl == null && _pickedImage == null) {
        updates['photoUrl'] = FieldValue.delete();
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update(updates);

      // 3. Update Firebase Auth display name
      await user.updateDisplayName(name);

      if (!mounted) return;
      _snack('Profile updated successfully ✓', success: true);

      // Small delay so snackbar is visible, then pop
      await Future.delayed(const Duration(milliseconds: 700));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      _snack('Update failed. Please try again.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _snack(String msg, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(
        children: [
          Icon(
            success ? Icons.check_circle_outline : Icons.error_outline,
            color: Colors.white,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(msg)),
        ],
      ),
      backgroundColor: success ? Colors.teal : Colors.redAccent,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(12),
    ));
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Gradient background (matches rest of app) ────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0F2027),
                  Color(0xFF203A43),
                  Color(0xFF2C5364),
                ],
              ),
            ),
          ),

          SafeArea(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.white))
                : Column(
                    children: [
                      // ── AppBar row ───────────────────────────────────────
                      Padding(
                        padding:
                            const EdgeInsets.fromLTRB(4, 12, 16, 0),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back_ios,
                                  color: Colors.white),
                              onPressed: () => Navigator.pop(context),
                            ),
                            const Expanded(
                              child: Text(
                                'Edit Profile',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            // Save button in top-right for quick access
                            TextButton(
                              onPressed: _isSaving ? null : _saveProfile,
                              child: Text(
                                'Save',
                                style: TextStyle(
                                  color: _isSaving
                                      ? Colors.white30
                                      : Colors.tealAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // ── Scrollable body ──────────────────────────────────
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                          child: Column(
                            children: [
                              // ── Avatar ─────────────────────────────────
                              _buildAvatar(),

                              const SizedBox(height: 8),

                              // Email (read-only, shown below avatar)
                              Text(
                                _email,
                                style: const TextStyle(
                                    color: Colors.white60, fontSize: 13),
                              ),

                              const SizedBox(height: 32),

                              // ── Form fields ───────────────────────────
                              _buildFormCard(),

                              const SizedBox(height: 20),

                              // ── Branch selector ───────────────────────
                              _buildBranchCard(),

                              const SizedBox(height: 20),

                              // ── Info note ─────────────────────────────
                              _buildInfoNote(),

                              const SizedBox(height: 28),

                              // ── Save button ───────────────────────────
                              _buildSaveButton(),

                              const SizedBox(height: 40),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
          ),

          // ── Upload progress overlay ──────────────────────────────────────
          if (_uploadProgress != null)
            _buildUploadOverlay(),

          // ── Full-screen loading overlay ──────────────────────────────────
          if (_isSaving && _uploadProgress == null)
            Container(
              color: Colors.black45,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.tealAccent),
              ),
            ),
        ],
      ),
    );
  }

  // ── Avatar widget ──────────────────────────────────────────────────────────
  Widget _buildAvatar() {
    // Determine which image to show: newly picked > existing URL > initials
    ImageProvider? imageProvider;
    if (_pickedImage != null) {
      imageProvider = FileImage(_pickedImage!);
    } else if (_existingPhotoUrl != null &&
        _existingPhotoUrl!.isNotEmpty) {
      imageProvider = NetworkImage(_existingPhotoUrl!);
    }

    final name    = _nameCtrl.text;
    final initials = name.isNotEmpty
        ? name.trim().split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join().toUpperCase()
        : '?';

    return GestureDetector(
      onTap: _showImageSourceSheet,
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          // Avatar circle
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.tealAccent.withOpacity(0.5),
                width: 2.5,
              ),
              color: Colors.teal.withOpacity(0.3),
            ),
            child: ClipOval(
              child: imageProvider != null
                  ? Image(
                      image: imageProvider,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _initialsAvatar(initials),
                    )
                  : _initialsAvatar(initials),
            ),
          ),

          // Edit badge
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.teal,
              border: Border.all(color: Colors.black, width: 2),
            ),
            child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
          ),
        ],
      ),
    );
  }

  Widget _initialsAvatar(String initials) {
    return Center(
      child: Text(
        initials,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 36,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // ── Form card (name + email display) ──────────────────────────────────────
  Widget _buildFormCard() {
    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _FieldLabel(text: 'Full Name'),
          const SizedBox(height: 8),
          TextField(
            controller: _nameCtrl,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            textCapitalization: TextCapitalization.words,
            decoration: _inputDecoration(
              hint: 'Enter your full name',
              icon: Icons.person_outline,
            ),
          ),

          const SizedBox(height: 20),

          const _FieldLabel(text: 'Email Address'),
          const SizedBox(height: 8),

          // Email is read-only — shown in a disabled-looking field
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Row(
              children: [
                const Icon(Icons.email_outlined, color: Colors.white30, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _email.isNotEmpty ? _email : 'No email',
                    style: const TextStyle(color: Colors.white38, fontSize: 14),
                  ),
                ),
                const Icon(Icons.lock_outline, color: Colors.white70, size: 14),
              ],
            ),
          ),

          const SizedBox(height: 4),
          const Padding(
            padding: EdgeInsets.only(left: 4),
            child: Text(
              'Email cannot be changed',
              style: TextStyle(color: Colors.white30, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  // ── Branch selector card ───────────────────────────────────────────────────
  Widget _buildBranchCard() {
    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _FieldLabel(text: 'Engineering Branch'),
          const SizedBox(height: 4),
          const Text(
            'Used for the branch leaderboard',
            style: TextStyle(color: Colors.white38, fontSize: 11),
          ),
          const SizedBox(height: 14),

          // Wrap of selectable chips
          Wrap(
            spacing:  8,
            runSpacing: 8,
            children: _branches.map((branch) {
              final selected = branch == _selectedBranch;
              return GestureDetector(
                onTap: () => setState(() => _selectedBranch = branch),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected
                        ? Colors.teal
                        : Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selected
                          ? Colors.teal
                          : Colors.white.withOpacity(0.15),
                      width: selected ? 1.5 : 1,
                    ),
                  ),
                  child: Text(
                    branch,
                    style: TextStyle(
                      color: selected ? Colors.white : Colors.white60,
                      fontWeight: selected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── Info note card ─────────────────────────────────────────────────────────
  Widget _buildInfoNote() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.amber.withOpacity(0.25)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: Colors.amber, size: 16),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Profile photo is uploaded to Firebase Storage. '
              'Name changes are reflected immediately on leaderboards.',
              style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  // ── Save button ────────────────────────────────────────────────────────────
  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _isSaving ? null : _saveProfile,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.teal,
          disabledBackgroundColor: Colors.teal.withOpacity(0.3),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
        ),
        child: _isSaving
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2.5),
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_rounded, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Save Changes',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
      ),
    );
  }

  // ── Upload progress overlay ────────────────────────────────────────────────
  Widget _buildUploadOverlay() {
    final pct = ((_uploadProgress ?? 0) * 100).toInt();
    return Container(
      color: Colors.black54,
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 40),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF203A43),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.15)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Uploading Photo...',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15)),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _uploadProgress,
                  minHeight: 8,
                  backgroundColor: Colors.white12,
                  color: Colors.tealAccent,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '$pct%',
                style: const TextStyle(
                    color: Colors.tealAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Shared helpers ─────────────────────────────────────────────────────────
  Widget _glassCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withOpacity(0.08),
        border: Border.all(color: Colors.white.withOpacity(0.13)),
      ),
      child: child,
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText:  hint,
      hintStyle: const TextStyle(color: Colors.white30, fontSize: 14),
      prefixIcon: Icon(icon, color: Colors.white38, size: 18),
      filled:     true,
      fillColor:  Colors.white.withOpacity(0.06),
      contentPadding: const EdgeInsets.symmetric(
          horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.teal, width: 1.5),
      ),
    );
  }
}

// ── Small label widget used above each field ───────────────────────────────
class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white60,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
      ),
    );
  }
}
