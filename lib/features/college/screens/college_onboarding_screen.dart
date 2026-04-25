// BUG FIXED: Once the code dialog was dismissed after creation, it was gone forever.
// Now the profile always shows the college code (read from Firestore).
// FIXED: ElevatedButton infinite width crash in Row.
// UPDATED: College code length changed to 8 characters.
// ADDED: "View My Code" button on the Create tab for existing college members.
// ADDED: Copy button on the code display.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/glass_card.dart';
import '../services/college_service.dart';
import 'college_leaderboard_screen.dart';
import 'college_quiz_screen.dart';

class CollegeOnboardingScreen extends StatefulWidget {
  const CollegeOnboardingScreen({super.key});

  @override
  State<CollegeOnboardingScreen> createState() =>
      _CollegeOnboardingScreenState();
}

class _CollegeOnboardingScreenState extends State<CollegeOnboardingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _joinCodeCtrl = TextEditingController();
  final _createNameCtrl = TextEditingController();
  bool _loading = false;

  final List<String> _branches = [
    'CSE', 'ECE', 'ME', 'CE', 'EE', 'IT', 'BT', 'Other',
  ];
  String _selectedBranch = 'CSE';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadExistingBranch();
  }

  Future<void> _loadExistingBranch() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    final branch = snap.data()?['branch'] as String?;
    if (branch != null && _branches.contains(branch)) {
      setState(() => _selectedBranch = branch);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _joinCodeCtrl.dispose();
    _createNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _joinCollege() async {
    if (_loading) return;
    final code = _joinCodeCtrl.text.trim();
    if (code.isEmpty) {
      _snack('Enter a college code');
      return;
    }
    // ✅ UPDATED: 8 char validation
    if (code.length != 8) {
      _snack('College code must be 8 characters');
      return;
    }

    setState(() => _loading = true);
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({'branch': _selectedBranch});

      await CollegeService.joinCollege(code: code);
      if (!mounted) return;
      _snack('Joined college successfully! 🎉', success: true);
      Navigator.pop(context, true);
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createCollege() async {
    if (_loading) return;
    final name = _createNameCtrl.text.trim();
    if (name.isEmpty) {
      _snack('Enter college name');
      return;
    }
    if (name.length < 3) {
      _snack('Name must be at least 3 characters');
      return;
    }

    setState(() => _loading = true);
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({'branch': _selectedBranch});

      final college = await CollegeService.createCollege(name: name);
      if (!mounted) return;

      await _showCodeDialog(college.code, college.name);
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showCodeDialog(String code, String name) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF203A43),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'College Created! 🎉',
          style:
              TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Share this code with your college mates.\nYou can also find it anytime via "My Code" button.',
              style: TextStyle(color: Colors.white70, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.teal, width: 2),
              ),
              child: Column(
                children: [
                  Text(
                    code,
                    style: const TextStyle(
                      color: Colors.tealAccent,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 6,
                    ),
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: code));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Code copied! 📋')));
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.teal.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: Colors.teal.withOpacity(0.4)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.copy,
                              color: Colors.tealAccent, size: 14),
                          SizedBox(width: 6),
                          Text(
                            'Copy Code',
                            style: TextStyle(
                                color: Colors.tealAccent, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // close dialog
                Navigator.pop(context, true); // return to parent
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 44),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Done',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  /// ✅ FIXED: Show existing college code — fetched from Firestore
  Future<void> _showMyCode() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    setState(() => _loading = true);
    try {
      final userSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      final collegeId = userSnap.data()?['collegeId'] as String?;
      if (collegeId == null) {
        _snack('You are not part of any college');
        return;
      }

      final collegeSnap = await FirebaseFirestore.instance
          .collection('colleges')
          .doc(collegeId)
          .get();
      final code = collegeSnap.data()?['code'] as String?;
      final name = collegeSnap.data()?['name'] as String? ?? '';

      if (code == null || !mounted) return;
      await _showCodeDialog(code, name);
    } catch (e) {
      _snack('Could not load code: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg, {bool success = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: success ? Colors.teal : Colors.redAccent,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Container(
              decoration: const BoxDecoration(
                  gradient: AppColors.mainGradient)),

          SafeArea(
            child: Column(
              children: [
                // ── Header ────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 16, 16, 0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_ios,
                            color: Colors.white),
                      ),
                      const Expanded(
                        child: Text(
                          'College System',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      // ✅ Fixed: SizedBox so TextButton doesn't overflow
                      SizedBox(
                        width: 80,
                        child: TextButton(
                          onPressed: _showMyCode,
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                          ),
                          child: const Text(
                            'My Code',
                            style: TextStyle(
                                color: Colors.tealAccent, fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: 24, vertical: 6),
                  child: Text(
                    'Join your college community and compete on the leaderboard',
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(color: Colors.white60, fontSize: 13),
                  ),
                ),

                const SizedBox(height: 12),

                // ── Tabs ──────────────────────────────────────────────────
                Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(
                      color: Colors.teal,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white60,
                    dividerColor: Colors.transparent,
                    tabs: const [
                      Tab(text: 'Join College'),
                      Tab(text: 'Create College'),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // ── Branch Selector ───────────────────────────────────────
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24),
                  child: GlassCard(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        const Icon(Icons.school_outlined,
                            color: Colors.white70),
                        const SizedBox(width: 12),
                        const Text('Branch:',
                            style: TextStyle(color: Colors.white70)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedBranch,
                              dropdownColor: const Color(0xFF203A43),
                              style: const TextStyle(color: Colors.white),
                              isExpanded: true,
                              items: _branches
                                  .map((b) => DropdownMenuItem(
                                        value: b,
                                        child: Text(b),
                                      ))
                                  .toList(),
                              onChanged: (v) {
                                if (v != null) {
                                  setState(() => _selectedBranch = v);
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildJoinTab(),
                      _buildCreateTab(),
                    ],
                  ),
                ),
              ],
            ),
          ),

          if (_loading)
            Container(
              color: Colors.black45,
              child: const Center(
                child: CircularProgressIndicator(
                    color: Colors.tealAccent),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildJoinTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Enter College Code',
                  style:
                      TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _joinCodeCtrl,
                  textCapitalization: TextCapitalization.characters,
                  style: const TextStyle(
                    color: Colors.tealAccent,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 6,
                  ),
                  // ✅ UPDATED: 8 character code
                  maxLength: 8,
                  decoration: InputDecoration(
                    // ✅ UPDATED: 8 char hint
                    hintText: 'ABC12345',
                    hintStyle: TextStyle(
                      color: Colors.white.withOpacity(0.2),
                      fontSize: 24,
                      letterSpacing: 6,
                    ),
                    counterText: '',
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.08),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: Colors.teal, width: 1.5),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _loading ? null : _joinCollege,
              icon: const Icon(Icons.group_add),
              label: const Text(
                'Join College',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'College Name',
                  style:
                      TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _createNameCtrl,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 16),
                  decoration: InputDecoration(
                    hintText: 'e.g. IIT Delhi, NIT Trichy...',
                    hintStyle:
                        const TextStyle(color: Colors.white38),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.08),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                          color: Colors.teal, width: 1.5),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          GlassCard(
            padding: const EdgeInsets.all(14),
            child: const Row(
              children: [
                Icon(Icons.info_outline,
                    color: Colors.amber, size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'A unique 8-character code is generated. '
                    'You can always view it again from the "My Code" button above.',
                    style: TextStyle(
                        color: Colors.white70, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _loading ? null : _createCollege,
              icon: const Icon(Icons.add_business),
              label: const Text(
                'Create College',
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
