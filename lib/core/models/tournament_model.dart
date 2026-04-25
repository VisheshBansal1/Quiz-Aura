import 'package:cloud_firestore/cloud_firestore.dart';

enum TournamentStatus { upcoming, active, finished, cancelled }

/// ───────────────── TOURNAMENT MODEL ─────────────────
class TournamentModel {
  final String id;
  final String title;
  final String description;
  final String createdBy;
  final TournamentStatus status;

  final int maxParticipants;
  final int participantCount;

  final int currentRound;
  final int totalRounds;

  final DateTime startAt;

  /// When the tournament closes (no more playing allowed).
  /// Auto-set to lastRound.endAt + 30 min on creation,
  /// or updated manually by admin via "End Tournament Now".
  final DateTime? endAt;

  final String prizeDescription;
  final int entryCoins;

  final DateTime? createdAt;

  const TournamentModel({
    required this.id,
    required this.title,
    required this.description,
    required this.createdBy,
    required this.status,
    required this.maxParticipants,
    required this.participantCount,
    required this.currentRound,
    required this.totalRounds,
    required this.startAt,
    this.endAt,
    required this.prizeDescription,
    required this.entryCoins,
    this.createdAt,
  });

  factory TournamentModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};

    return TournamentModel(
      id: doc.id,
      title: d['title'] ?? 'Tournament',
      description: d['description'] ?? '',
      createdBy: d['createdBy'] ?? '',
      status: _parseStatus(d['status'] as String?),

      maxParticipants: (d['maxParticipants'] ?? 100) as int,
      participantCount: (d['participantCount'] ?? 0) as int,

      currentRound: (d['currentRound'] ?? 0) as int,
      totalRounds: (d['totalRounds'] ?? 3) as int,

      startAt: (d['startAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endAt: (d['endAt'] as Timestamp?)?.toDate(),

      prizeDescription: d['prizeDescription'] ?? '',
      entryCoins: (d['entryCoins'] ?? 0) as int,

      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  static TournamentStatus _parseStatus(String? s) {
    switch (s?.toLowerCase()) {
      case 'active':
        return TournamentStatus.active;
      case 'finished':
        return TournamentStatus.finished;
      case 'cancelled':
        return TournamentStatus.cancelled;
      default:
        return TournamentStatus.upcoming;
    }
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'description': description,
        'createdBy': createdBy,
        'status': status.name,
        'maxParticipants': maxParticipants,
        'participantCount': participantCount,
        'currentRound': currentRound,
        'totalRounds': totalRounds,
        'startAt': Timestamp.fromDate(startAt),
        if (endAt != null) 'endAt': Timestamp.fromDate(endAt!),
        'prizeDescription': prizeDescription,
        'entryCoins': entryCoins,
        'createdAt': FieldValue.serverTimestamp(),
      };

  /// True only when the tournament is still upcoming AND we're before startAt.
  bool get isJoinable =>
      status == TournamentStatus.upcoming &&
      DateTime.now().isBefore(startAt);

  /// Client-side effective status — derived from Firestore status + real clock.
  /// This means UI always shows reality even if admin hasn't manually updated Firestore.
  TournamentStatus get effectiveStatus {
    // Admin-set terminal states always win.
    if (status == TournamentStatus.finished) return TournamentStatus.finished;
    if (status == TournamentStatus.cancelled) return TournamentStatus.cancelled;

    final now = DateTime.now();

    // If endAt is set and passed → treat as finished regardless of Firestore status.
    if (endAt != null && now.isAfter(endAt!)) return TournamentStatus.finished;

    if (status == TournamentStatus.active) return TournamentStatus.active;

    // Upcoming → flip to active once startAt passes.
    if (now.isAfter(startAt)) return TournamentStatus.active;
    return TournamentStatus.upcoming;
  }
}

/// ───────────────── ROUND MODEL ─────────────────
class TournamentRound {
  final String id;
  final int roundNumber;
  final String quizId;
  final DateTime startAt;
  final DateTime endAt;
  final int qualifyCount;

  const TournamentRound({
    required this.id,
    required this.roundNumber,
    required this.quizId,
    required this.startAt,
    required this.endAt,
    required this.qualifyCount,
  });

  factory TournamentRound.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};

    return TournamentRound(
      id: doc.id,
      roundNumber: (d['roundNumber'] ?? 1) as int,
      quizId: d['quizId'] ?? '',
      startAt:
          (d['startAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endAt:
          (d['endAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      qualifyCount: (d['qualifyCount'] ?? 10) as int,
    );
  }

  Map<String, dynamic> toMap() => {
        'roundNumber': roundNumber,
        'quizId': quizId,
        'startAt': Timestamp.fromDate(startAt),
        'endAt': Timestamp.fromDate(endAt),
        'qualifyCount': qualifyCount,
      };
}

/// ───────────────── PARTICIPANT MODEL ─────────────────
class TournamentParticipant {
  final String uid;
  final String name;
  final int currentRound;
  final bool eliminated;
  final List<Map<String, dynamic>> roundScores;

  const TournamentParticipant({
    required this.uid,
    required this.name,
    required this.currentRound,
    required this.eliminated,
    required this.roundScores,
  });

  factory TournamentParticipant.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};

    return TournamentParticipant(
      uid: doc.id,
      name: d['name'] ?? 'Player',
      currentRound: (d['currentRound'] ?? 1) as int,
      eliminated: (d['eliminated'] ?? false) as bool,

      // 🔥 SAFE PARSING
      roundScores: (d['roundScores'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'currentRound': currentRound,
        'eliminated': eliminated,
        'roundScores': roundScores,
        'joinedAt': FieldValue.serverTimestamp(),
      };
}
