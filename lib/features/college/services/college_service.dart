import 'dart:math';
import 'package:QuizSphere/core/models/college_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CollegeService {
  static final _db = FirebaseFirestore.instance;

  static const String _chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  // ── Generate unique 8-char college code ──────────────────────────────────
  // ✅ UPDATED: Changed from 6 to 8 characters for more uniqueness
  static String _generateCode() {
    final rand = Random.secure();
    return List.generate(8, (_) => _chars[rand.nextInt(_chars.length)]).join();
  }

  // ── CREATE COLLEGE ────────────────────────────────────────────────────────
  static Future<CollegeModel> createCollege({
    required String name,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('Not logged in');

    // Check if user already belongs to a college
    final userSnap = await _db.collection('users').doc(uid).get();
    if (userSnap.data()?['collegeId'] != null) {
      throw Exception(
          'You are already part of a college. Leave it first.');
    }

    // Generate unique code (retry if collision)
    String code = _generateCode();
    bool unique = false;
    int attempts = 0;
    while (!unique && attempts < 5) {
      final existing = await _db
          .collection('colleges')
          .where('code', isEqualTo: code)
          .limit(1)
          .get();
      unique = existing.docs.isEmpty;
      if (!unique) code = _generateCode();
      attempts++;
    }
    if (!unique) {
      throw Exception('Failed to generate unique code. Try again.');
    }

    // Re-fetch user data AFTER the screen may have updated branch
    final freshUserSnap =
        await _db.collection('users').doc(uid).get();
    final userData = freshUserSnap.data() ?? {};

    // Create college document
    final docRef = _db.collection('colleges').doc();
    final batch = _db.batch();

    batch.set(docRef, {
      'name': name.trim(),
      'code': code,
      'createdBy': uid,
      'memberCount': 1,
      'totalXp': (userData['totalXp'] ?? 0) as int,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Add creator as first member
    batch.set(
      docRef.collection('members').doc(uid),
      {
        'name': userData['name'] ?? 'User',
        'xp': (userData['totalXp'] ?? 0) as int,
        'branch': userData['branch'] ?? 'CSE',
        'joinedAt': FieldValue.serverTimestamp(),
      },
    );

    // Link college to user profile
    batch.update(_db.collection('users').doc(uid), {
      'collegeId': docRef.id,
      'collegeName': name.trim(),
    });

    await batch.commit();

    return CollegeModel(
      id: docRef.id,
      name: name.trim(),
      code: code,
      createdBy: uid,
      memberCount: 1,
    );
  }

  // ── JOIN COLLEGE BY CODE ──────────────────────────────────────────────────
  static Future<CollegeModel> joinCollege({required String code}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('Not logged in');

    final cleanCode = code.trim().toUpperCase();
    // ✅ UPDATED: Validate 8 character code
    if (cleanCode.length != 8) {
      throw Exception('College code must be exactly 8 characters');
    }

    // Check if user already in a college
    final userSnap = await _db.collection('users').doc(uid).get();
    if (userSnap.data()?['collegeId'] != null) {
      throw Exception(
          'You are already part of a college. Leave it first.');
    }

    // Find college by code
    final query = await _db
        .collection('colleges')
        .where('code', isEqualTo: cleanCode)
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      throw Exception('No college found with that code');
    }

    final collegeDoc = query.docs.first;
    final collegeData = collegeDoc.data();
    final userData = userSnap.data() ?? {};

    // Check if already a member
    final memberSnap = await collegeDoc.reference
        .collection('members')
        .doc(uid)
        .get();
    if (memberSnap.exists) {
      throw Exception('Already a member of this college');
    }

    final batch = _db.batch();

    // Add to members subcollection
    batch.set(
      collegeDoc.reference.collection('members').doc(uid),
      {
        'name': userData['name'] ?? 'User',
        'xp': (userData['totalXp'] ?? 0) as int,
        'branch': userData['branch'] ?? 'CSE',
        'joinedAt': FieldValue.serverTimestamp(),
      },
    );

    // Increment member count + xp
    batch.update(collegeDoc.reference, {
      'memberCount': FieldValue.increment(1),
      'totalXp':
          FieldValue.increment((userData['totalXp'] ?? 0) as int),
    });

    // Link user to college
    batch.update(_db.collection('users').doc(uid), {
      'collegeId': collegeDoc.id,
      'collegeName': collegeData['name'] ?? '',
    });

    await batch.commit();

    return CollegeModel.fromFirestore(collegeDoc);
  }

  // ── LEAVE COLLEGE ─────────────────────────────────────────────────────────
  static Future<void> leaveCollege() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('Not logged in');

    final userSnap = await _db.collection('users').doc(uid).get();
    final collegeId = userSnap.data()?['collegeId'] as String?;
    if (collegeId == null) throw Exception('Not part of any college');

    final userXp = (userSnap.data()?['totalXp'] ?? 0) as int;
    final batch = _db.batch();

    // Remove from members
    batch.delete(
      _db
          .collection('colleges')
          .doc(collegeId)
          .collection('members')
          .doc(uid),
    );

    // Decrement college stats
    batch.update(_db.collection('colleges').doc(collegeId), {
      'memberCount': FieldValue.increment(-1),
      'totalXp': FieldValue.increment(-userXp),
    });

    // Remove college link from user
    batch.update(_db.collection('users').doc(uid), {
      'collegeId': FieldValue.delete(),
      'collegeName': FieldValue.delete(),
    });

    await batch.commit();
  }

  // ── GET COLLEGE MEMBERS (stream) ──────────────────────────────────────────
  static Stream<List<CollegeMemberModel>> membersStream(
      String collegeId) {
    return _db
        .collection('colleges')
        .doc(collegeId)
        .collection('members')
        .orderBy('xp', descending: true)
        .limit(100)
        .snapshots()
        .map((s) =>
            s.docs.map(CollegeMemberModel.fromFirestore).toList());
  }

  // ── GET COLLEGE DETAILS (stream) ──────────────────────────────────────────
  static Stream<CollegeModel?> collegeStream(String collegeId) {
    return _db
        .collection('colleges')
        .doc(collegeId)
        .snapshots()
        .map((s) => s.exists ? CollegeModel.fromFirestore(s) : null);
  }

  // ── UPDATE MEMBER XP (call after quiz submit) ─────────────────────────────
  static Future<void> syncMemberXp({
    required String collegeId,
    required String userId,
    required int newTotalXp,
    required int xpGained,
  }) async {
    try {
      final batch = _db.batch();
      batch.update(
        _db
            .collection('colleges')
            .doc(collegeId)
            .collection('members')
            .doc(userId),
        {'xp': newTotalXp, 'updatedAt': FieldValue.serverTimestamp()},
      );
      batch.update(
        _db.collection('colleges').doc(collegeId),
        {'totalXp': FieldValue.increment(xpGained)},
      );
      await batch.commit();
    } catch (_) {
      // Non-critical — swallow to not break quiz flow
    }
  }
}
