// ============================================================
// FILE: lib/features/battle/models/battle_v2_model.dart
// New battle model aligned with the required Firestore structure:
//   battles/{battleId}/
//     hostId, opponentId, quizId, status, winnerId, createdAt
//     players/{userId}/
//       score, submitted
// This is a SEPARATE model from the existing BattleRoomModel.
// The existing BattleRoomModel and BattleService are NOT modified.
// ============================================================

import 'package:cloud_firestore/cloud_firestore.dart';

enum BattleV2Status { waiting, active, finished, cancelled }

class BattleV2Model {
  final String id;
  final String hostId;
  final String opponentId; // empty while waiting
  final String quizId;
  final BattleV2Status status;
  final String? winnerId;
  final DateTime createdAt;

  const BattleV2Model({
    required this.id,
    required this.hostId,
    required this.opponentId,
    required this.quizId,
    required this.status,
    this.winnerId,
    required this.createdAt,
  });

  factory BattleV2Model.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return BattleV2Model(
      id: doc.id,
      hostId: d['hostId'] as String? ?? '',
      opponentId: d['opponentId'] as String? ?? '',
      quizId: d['quizId'] as String? ?? '',
      status: _parseStatus(d['status'] as String?),
      winnerId: d['winnerId'] as String?,
      createdAt:
          (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  static BattleV2Status _parseStatus(String? s) {
    switch (s) {
      case 'active':
        return BattleV2Status.active;
      case 'finished':
        return BattleV2Status.finished;
      case 'cancelled':
        return BattleV2Status.cancelled;
      default:
        return BattleV2Status.waiting;
    }
  }

  bool get isWaiting => status == BattleV2Status.waiting;
  bool get isActive => status == BattleV2Status.active;
  bool get isFinished => status == BattleV2Status.finished;
}

class BattleV2Player {
  final String uid;
  final String name;
  final int score;
  final bool submitted;

  const BattleV2Player({
    required this.uid,
    required this.name,
    required this.score,
    required this.submitted,
  });

  factory BattleV2Player.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return BattleV2Player(
      uid: doc.id,
      name: d['name'] as String? ?? 'Player',
      score: (d['score'] ?? 0) as int,
      submitted: (d['submitted'] ?? false) as bool,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'score': score,
        'submitted': submitted,
        'updatedAt': FieldValue.serverTimestamp(),
      };
}
