/// Single source of truth for all Firestore collection/document paths.
/// Never hardcode collection names in screens — use these constants.
class FirestorePaths {
  FirestorePaths._();

  // ── Existing collections (DO NOT RENAME) ─────────────────────────────────
  static const String users        = 'users';
  static const String topics       = 'topics';
  static const String quizzes      = 'quizzes';
  static const String dailyQuizzes = 'dailyQuizzes';
  static const String questions    = 'questions';
  static const String attempts     = 'attempts';
  static const String leaderboard  = 'leaderboard';

  // ── New collections ────────────────────────────────────────────────────────
  static const String colleges          = 'colleges';
  static const String collegeMembers    = 'members';
  static const String battles           = 'battles';
  static const String battleScores      = 'scores';
  static const String tournaments       = 'tournaments';
  static const String tournamentRounds  = 'rounds';
  static const String tournamentPlayers = 'participants';
  static const String notifications     = 'notifications';
  static const String notifItems        = 'items';
  static const String performanceStats  = 'performanceStats';
  static const String globalLeaderboard = 'globalLeaderboard';

  // ── Path helpers ──────────────────────────────────────────────────────────
  static String userDoc(String uid)            => '$users/$uid';
  static String collegeDoc(String id)          => '$colleges/$id';
  static String battleDoc(String id)           => '$battles/$id';
  static String tournamentDoc(String id)       => '$tournaments/$id';
  static String performanceDoc(String uid)     => '$performanceStats/$uid';
  static String notifCollection(String uid)    => '$notifications/$uid/$notifItems';
}
