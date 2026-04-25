import 'package:cloud_firestore/cloud_firestore.dart';

class CollegeModel {
  final String id;
  final String name;
  final String code;        // Unique 6-char join code
  final String createdBy;
  final int memberCount;
  final int totalXp;
  final DateTime? createdAt;

  const CollegeModel({
    required this.id,
    required this.name,
    required this.code,
    required this.createdBy,
    this.memberCount = 0,
    this.totalXp = 0,
    this.createdAt,
  });

  factory CollegeModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return CollegeModel(
      id:          doc.id,
      name:        d['name']        ?? '',
      code:        d['code']        ?? '',
      createdBy:   d['createdBy']   ?? '',
      memberCount: (d['memberCount']?? 0) as int,
      totalXp:     (d['totalXp']    ?? 0) as int,
      createdAt:   (d['createdAt']  as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
    'name':        name,
    'code':        code,
    'createdBy':   createdBy,
    'memberCount': memberCount,
    'totalXp':     totalXp,
    'createdAt':   FieldValue.serverTimestamp(),
  };
}

class CollegeMemberModel {
  final String uid;
  final String name;
  final int xp;
  final String branch;
  final DateTime? joinedAt;

  const CollegeMemberModel({
    required this.uid,
    required this.name,
    required this.xp,
    required this.branch,
    this.joinedAt,
  });

  factory CollegeMemberModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return CollegeMemberModel(
      uid:      doc.id,
      name:     d['name']     ?? 'User',
      xp:       (d['xp']      ?? 0) as int,
      branch:   d['branch']   ?? 'CSE',
      joinedAt: (d['joinedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
    'name':     name,
    'xp':       xp,
    'branch':   branch,
    'joinedAt': FieldValue.serverTimestamp(),
  };
}
