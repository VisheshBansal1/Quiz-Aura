// ============================================================
// FILE: lib/models/user_model.dart
//
// BUGS FIXED vs original:
//  FIX 1: Added missing `photoUrl` field.  ProfileScreen and
//          EditProfileScreen both write/read 'photoUrl' from
//          Firestore, but UserModel never had this field — so
//          any code that built a UserModel lost the photo URL.
//  FIX 2: `levelProgress` guarded against division-by-zero.
//          If requiredXp is ever 0 (corrupt data), the old
//          `xp / requiredXp` would throw an IntegerDivisionByZero
//          error and crash the XP bar widget.
//  FIX 3: `fromFirestore` now also reads 'photoUrl' and falls
//          back to 'profileImage' for backwards compatibility.
//  FIX 4: `toMap` includes 'photoUrl' so writes are complete.
//  FIX 5: `copyWith` exposes `photoUrl` so EditProfileScreen
//          can produce an updated UserModel without re-fetching.
// ============================================================

import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String name;
  final String email;
  final String provider;

  // ── Existing XP / Level fields ───────────────────────────────────────────
  final int xp;
  final int totalXp;
  final int level;
  final int requiredXp;
  final int streakCount;

  // ── FIX 1: photoUrl was missing from UserModel ───────────────────────────
  final String photoUrl;   // Firebase Storage download URL (or '' if none)

  // ── Other fields ─────────────────────────────────────────────────────────
  final String? collegeId;
  final String? collegeName;
  final String  branch;
  final int     coins;
  final List<String> badges;
  final String? fcmToken;
  final int     totalQuizzes;
  final int     weeklyXp;
  final int     monthlyXp;
  final Map<String, dynamic> accuracyByTopic;

  final DateTime? createdAt;
  final DateTime? lastLoginAt;

  const UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.provider,
    this.xp           = 0,
    this.totalXp      = 0,
    this.level        = 1,
    this.requiredXp   = 100,
    this.streakCount  = 0,
    this.photoUrl     = '',    // FIX 1
    this.collegeId,
    this.collegeName,
    this.branch       = 'CSE',
    this.coins        = 0,
    this.badges       = const [],
    this.fcmToken,
    this.totalQuizzes = 0,
    this.weeklyXp     = 0,
    this.monthlyXp    = 0,
    this.accuracyByTopic = const {},
    this.createdAt,
    this.lastLoginAt,
  });

  factory UserModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return UserModel(
      uid:          doc.id,
      name:         (d['name']      as String?) ?? 'User',
      email:        (d['email']     as String?) ?? '',
      provider:     (d['provider']  as String?) ?? 'password',
      xp:           (d['xp']        ?? 0)   as int,
      totalXp:      (d['totalXp']   ?? 0)   as int,
      level:        (d['level']     ?? 1)   as int,
      requiredXp:   (d['requiredXp']?? 100) as int,
      streakCount:  (d['streakCount']?? 0)  as int,

      // FIX 3: read photoUrl with fallback to legacy profileImage field
      photoUrl:     (d['photoUrl']     as String?)
                 ?? (d['profileImage'] as String?)
                 ?? '',

      collegeId:    d['collegeId']    as String?,
      collegeName:  d['collegeName']  as String?,
      branch:       (d['branch']      as String?) ?? 'CSE',
      coins:        (d['coins']       ?? 0) as int,
      badges:       List<String>.from(d['badges'] ?? []),
      fcmToken:     d['fcmToken']     as String?,
      totalQuizzes: (d['totalQuizzes']?? 0) as int,
      weeklyXp:     (d['weeklyXp']    ?? 0) as int,
      monthlyXp:    (d['monthlyXp']   ?? 0) as int,
      accuracyByTopic:
          Map<String, dynamic>.from(d['accuracyByTopic'] ?? {}),
      createdAt:    (d['createdAt']   as Timestamp?)?.toDate(),
      lastLoginAt:  (d['lastLoginAt'] as Timestamp?)?.toDate(),
    );
  }

  // FIX 4: toMap includes photoUrl
  Map<String, dynamic> toMap() => {
    'uid':             uid,
    'name':            name,
    'email':           email,
    'provider':        provider,
    'xp':              xp,
    'totalXp':         totalXp,
    'level':           level,
    'requiredXp':      requiredXp,
    'streakCount':     streakCount,
    'photoUrl':        photoUrl,       // FIX 4
    'collegeId':       collegeId,
    'collegeName':     collegeName,
    'branch':          branch,
    'coins':           coins,
    'badges':          badges,
    'fcmToken':        fcmToken,
    'totalQuizzes':    totalQuizzes,
    'weeklyXp':        weeklyXp,
    'monthlyXp':       monthlyXp,
    'accuracyByTopic': accuracyByTopic,
  };

  // FIX 5: copyWith exposes photoUrl
  UserModel copyWith({
    String?              name,
    String?              photoUrl,
    String?              branch,
    String?              collegeId,
    String?              collegeName,
    int?                 coins,
    List<String>?        badges,
    String?              fcmToken,
    int?                 weeklyXp,
    int?                 monthlyXp,
    int?                 totalQuizzes,
    Map<String, dynamic>? accuracyByTopic,
  }) {
    return UserModel(
      uid:             uid,
      name:            name            ?? this.name,
      email:           email,
      provider:        provider,
      xp:              xp,
      totalXp:         totalXp,
      level:           level,
      requiredXp:      requiredXp,
      streakCount:     streakCount,
      photoUrl:        photoUrl        ?? this.photoUrl,   // FIX 5
      collegeId:       collegeId       ?? this.collegeId,
      collegeName:     collegeName     ?? this.collegeName,
      branch:          branch          ?? this.branch,
      coins:           coins           ?? this.coins,
      badges:          badges          ?? this.badges,
      fcmToken:        fcmToken        ?? this.fcmToken,
      totalQuizzes:    totalQuizzes    ?? this.totalQuizzes,
      weeklyXp:        weeklyXp        ?? this.weeklyXp,
      monthlyXp:       monthlyXp       ?? this.monthlyXp,
      accuracyByTopic: accuracyByTopic ?? this.accuracyByTopic,
      createdAt:       createdAt,
      lastLoginAt:     lastLoginAt,
    );
  }

  /// Display rank title — matches LevelService.getRankTitle()
  String get rankTitle {
    if (level < 5)  return 'Beginner';
    if (level < 10) return 'Explorer';
    if (level < 20) return 'Challenger';
    if (level < 30) return 'Master';
    return 'Legend';
  }

  /// FIX 2: Guard against division by zero when requiredXp is corrupt
  double get levelProgress {
    if (requiredXp <= 0) return 0.0;
    return (xp / requiredXp).clamp(0.0, 1.0);
  }
}