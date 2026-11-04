// ============================================================
// FILE: lib/features/battle/models/battle_models.dart
// View models for the 1v1 battle system (free Spark plan version:
// Firestore + security rules only, no Cloud Functions).
// ============================================================

import 'package:cloud_firestore/cloud_firestore.dart';

enum BattleStatus { waiting, lobby, live, cancelled, unknown }

BattleStatus parseBattleStatus(String? s) {
  switch (s) {
    case 'waiting':
      return BattleStatus.waiting;
    case 'lobby':
      return BattleStatus.lobby;
    case 'live':
      return BattleStatus.live;
    case 'cancelled':
      return BattleStatus.cancelled;
    default:
      return BattleStatus.unknown;
  }
}

int _int(dynamic v, [int d = 0]) => v is num ? v.toInt() : d;
String _str(dynamic v, [String d = '']) => v is String ? v : d;
Map<String, dynamic> _map(dynamic v) =>
    v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

class BattleSettings {
  final int questionCount;
  final int questionSeconds;
  final int revealSeconds;
  final int answerGraceMs;

  const BattleSettings({
    this.questionCount = 10,
    this.questionSeconds = 15,
    this.revealSeconds = 3,
    this.answerGraceMs = 1500,
  });

  factory BattleSettings.fromMap(dynamic raw) {
    final m = _map(raw);
    return BattleSettings(
      questionCount: _int(m['questionCount'], 10),
      questionSeconds: _int(m['questionSeconds'], 15),
      revealSeconds: _int(m['revealSeconds'], 3),
      answerGraceMs: _int(m['answerGraceMs'], 1500),
    );
  }

  /// Clamps admin-supplied values into the ranges the security rules accept.
  factory BattleSettings.sanitized(Map<String, dynamic>? raw) {
    final m = raw ?? <String, dynamic>{};
    int clampInt(dynamic v, int d, int lo, int hi) {
      final n = v is num ? v.toInt() : d;
      return n < lo ? lo : (n > hi ? hi : n);
    }

    return BattleSettings(
      questionCount: clampInt(m['questionCount'], 10, 5, 20),
      questionSeconds: clampInt(m['questionSeconds'], 15, 5, 60),
      revealSeconds: clampInt(m['revealSeconds'], 3, 2, 10),
      answerGraceMs: clampInt(m['answerGraceMs'], 1500, 0, 3000),
    );
  }

  Map<String, dynamic> toMap() => {
        'questionCount': questionCount,
        'questionSeconds': questionSeconds,
        'revealSeconds': revealSeconds,
        'answerGraceMs': answerGraceMs,
      };

  int get periodMs => (questionSeconds + revealSeconds) * 1000;
}

class BattlePlayer {
  final String uid;
  final String name;
  final String photoUrl;
  final int rating;
  final int played;
  final int wins;
  final bool ready;

  const BattlePlayer({
    required this.uid,
    required this.name,
    required this.photoUrl,
    required this.rating,
    required this.played,
    required this.wins,
    required this.ready,
  });

  factory BattlePlayer.fromMap(String uid, dynamic raw) {
    final m = _map(raw);
    return BattlePlayer(
      uid: uid,
      name: _str(m['name'], 'Player'),
      photoUrl: _str(m['photoUrl']),
      rating: _int(m['rating'], 1000),
      played: _int(m['played']),
      wins: _int(m['wins']),
      ready: m['ready'] == true,
    );
  }

  /// Map stored inside battleMatches/{id}.players.{uid}.
  Map<String, dynamic> toMap() => {
        'name': name,
        'photoUrl': photoUrl,
        'rating': rating,
        'played': played,
        'wins': wins,
        'ready': ready,
      };

  double get winRate => played == 0 ? 0 : wins * 100 / played;
}

class BattleForfeit {
  final String by;
  final String reason; // left | disconnect
  final int? atMs;

  const BattleForfeit({required this.by, required this.reason, required this.atMs});
}

class BattleMatch {
  final String id;
  final BattleStatus status;
  final String mode; // quick | friend | private
  final String category;
  final String hostId;
  final String organizerId; // '' unless this is a referee-run battle
  final List<String> playerIds;
  final Map<String, BattlePlayer> players;
  final BattleSettings settings;
  final String? roomCode;
  final int? startAtMs;
  final int? endsAtMs;
  final BattleForfeit? forfeit;
  final Map<String, bool> settled;
  final String? cancelReason;

  const BattleMatch({
    required this.id,
    required this.status,
    required this.mode,
    required this.category,
    required this.hostId,
    required this.organizerId,
    required this.playerIds,
    required this.players,
    required this.settings,
    required this.roomCode,
    required this.startAtMs,
    required this.endsAtMs,
    required this.forfeit,
    required this.settled,
    required this.cancelReason,
  });

  factory BattleMatch.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? <String, dynamic>{};
    final ids = (d['playerIds'] is List)
        ? List<String>.from((d['playerIds'] as List).map((e) => e.toString()))
        : <String>[];
    final players = <String, BattlePlayer>{};
    _map(d['players']).forEach((uid, v) {
      players[uid] = BattlePlayer.fromMap(uid, v);
    });
    final settled = <String, bool>{};
    _map(d['settled']).forEach((uid, v) {
      settled[uid] = v == true;
    });
    BattleForfeit? forfeit;
    if (d['forfeit'] is Map) {
      final f = _map(d['forfeit']);
      final at = f['at'];
      forfeit = BattleForfeit(
        by: _str(f['by']),
        reason: _str(f['reason'], 'left'),
        atMs: at is Timestamp ? at.millisecondsSinceEpoch : null,
      );
    }
    return BattleMatch(
      id: doc.id,
      status: parseBattleStatus(d['status'] as String?),
      mode: _str(d['mode'], 'quick'),
      category: _str(d['category']),
      hostId: _str(d['hostId']),
      organizerId: _str(d['organizerId']),
      playerIds: ids,
      players: players,
      settings: BattleSettings.fromMap(d['settings']),
      roomCode: d['roomCode'] as String?,
      startAtMs: d['startAtMs'] is num ? (d['startAtMs'] as num).toInt() : null,
      endsAtMs: d['endsAtMs'] is num ? (d['endsAtMs'] as num).toInt() : null,
      forfeit: forfeit,
      settled: settled,
      cancelReason: d['cancelReason'] as String?,
    );
  }

  bool get isOrganized => mode == 'organized';

  String? opponentOf(String uid) {
    for (final id in playerIds) {
      if (id != uid) return id;
    }
    return null;
  }
}

class BattleQuestion {
  final int index;
  final String text;
  final List<String> options;

  const BattleQuestion({
    required this.index,
    required this.text,
    required this.options,
  });

  factory BattleQuestion.fromMap(Map<String, dynamic> m) {
    return BattleQuestion(
      index: _int(m['index']),
      text: _str(m['text']),
      options: (m['options'] is List)
          ? List<String>.from((m['options'] as List).map((e) => e.toString()))
          : <String>[],
    );
  }
}

/// A player's one-and-only answer for a round. `atMs` is the SERVER time the
/// rules stamped on it (request.time) — response time = atMs - round open.
class PlayerAnswer {
  final int choice;
  final int atMs;

  const PlayerAnswer({required this.choice, required this.atMs});
}

class BattleStats {
  final String uid;
  final String name;
  final String photoUrl;
  final int rating;
  final int peakRating;
  final int played;
  final int wins;
  final int losses;
  final int draws;
  final List<String> recentOpponents;
  final String lastBattleId;

  const BattleStats({
    required this.uid,
    this.name = '',
    this.photoUrl = '',
    this.rating = 1000,
    this.peakRating = 1000,
    this.played = 0,
    this.wins = 0,
    this.losses = 0,
    this.draws = 0,
    this.recentOpponents = const [],
    this.lastBattleId = '',
  });

  factory BattleStats.fromDoc(String uid, Map<String, dynamic>? d) {
    final m = d ?? <String, dynamic>{};
    final recent = <String>[];
    if (m['recentOpponents'] is List) {
      for (final r in (m['recentOpponents'] as List)) {
        recent.add(_str(_map(r)['name'], 'Player'));
      }
    }
    return BattleStats(
      uid: uid,
      name: _str(m['name']),
      photoUrl: _str(m['photoUrl']),
      rating: _int(m['rating'], 1000),
      peakRating: _int(m['peakRating'], 1000),
      played: _int(m['played']),
      wins: _int(m['wins']),
      losses: _int(m['losses']),
      draws: _int(m['draws']),
      recentOpponents: recent,
      lastBattleId: _str(m['lastBattleId']),
    );
  }

  double get winRate => played == 0 ? 0 : wins * 100 / played;
}

class BattleHistoryItem {
  final String battleId;
  final String opponentName;
  final int myScore;
  final int oppScore;
  final String result; // win | loss | draw
  final String resultStatus;
  final String mode;
  final int ratingDelta;
  final DateTime? completedAt;

  const BattleHistoryItem({
    required this.battleId,
    required this.opponentName,
    required this.myScore,
    required this.oppScore,
    required this.result,
    required this.resultStatus,
    required this.mode,
    required this.ratingDelta,
    required this.completedAt,
  });

  factory BattleHistoryItem.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? <String, dynamic>{};
    return BattleHistoryItem(
      battleId: doc.id,
      opponentName: _str(m['opponentName'], 'Player'),
      myScore: _int(m['myScore']),
      oppScore: _int(m['oppScore']),
      result: _str(m['result'], 'loss'),
      resultStatus: _str(m['resultStatus'], 'normal'),
      mode: _str(m['mode'], 'quick'),
      ratingDelta: _int(m['ratingDelta']),
      completedAt: (m['completedAt'] is Timestamp)
          ? (m['completedAt'] as Timestamp).toDate()
          : null,
    );
  }
}

class BattleInvite {
  final String code;
  final String battleId;
  final String hostId;
  final String hostName;
  final String status; // waiting | accepted | declined | expired | cancelled
  final int expiresAtMs;

  const BattleInvite({
    required this.code,
    required this.battleId,
    required this.hostId,
    required this.hostName,
    required this.status,
    required this.expiresAtMs,
  });

  factory BattleInvite.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final m = doc.data() ?? <String, dynamic>{};
    return BattleInvite(
      code: doc.id,
      battleId: _str(m['battleId']),
      hostId: _str(m['hostId']),
      hostName: _str(m['hostName'], 'A player'),
      status: _str(m['status'], 'waiting'),
      expiresAtMs: _int(m['expiresAtMs']),
    );
  }
}

class BattleUserHit {
  final String uid;
  final String name;
  final String photoUrl;

  const BattleUserHit({
    required this.uid,
    required this.name,
    required this.photoUrl,
  });
}
