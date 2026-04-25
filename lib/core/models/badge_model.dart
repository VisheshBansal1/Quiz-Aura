class BadgeModel {
  final String id;
  final String name;
  final String description;
  final String emoji;
  final String condition; // human-readable condition

  const BadgeModel({
    required this.id,
    required this.name,
    required this.description,
    required this.emoji,
    required this.condition,
  });

  // ── All available badges ───────────────────────────────────────────────────
  static const List<BadgeModel> all = [
    BadgeModel(
      id: 'first_quiz',
      name: 'First Step',
      emoji: '🎯',
      description: 'Completed your first quiz',
      condition: 'Complete 1 quiz',
    ),
    BadgeModel(
      id: 'streak_3',
      name: 'Hot Streak',
      emoji: '🔥',
      description: '3-day login streak',
      condition: 'Maintain a 3-day streak',
    ),
    BadgeModel(
      id: 'streak_7',
      name: 'Week Warrior',
      emoji: '⚡',
      description: '7-day login streak',
      condition: 'Maintain a 7-day streak',
    ),
    BadgeModel(
      id: 'streak_30',
      name: 'Streak Master',
      emoji: '👑',
      description: '30-day login streak',
      condition: 'Maintain a 30-day streak',
    ),
    BadgeModel(
      id: 'quiz_10',
      name: 'Quiz Enthusiast',
      emoji: '📚',
      description: 'Completed 10 quizzes',
      condition: 'Complete 10 quizzes',
    ),
    BadgeModel(
      id: 'quiz_50',
      name: 'Quiz Champion',
      emoji: '🏆',
      description: 'Completed 50 quizzes',
      condition: 'Complete 50 quizzes',
    ),
    BadgeModel(
      id: 'perfect_score',
      name: 'Perfectionist',
      emoji: '💯',
      description: 'Got 100% on any quiz',
      condition: 'Score 100% on a quiz',
    ),
    BadgeModel(
      id: 'battle_win',
      name: 'Battle Ready',
      emoji: '⚔️',
      description: 'Won your first battle',
      condition: 'Win 1 live battle',
    ),
    BadgeModel(
      id: 'battle_win_10',
      name: 'Gladiator',
      emoji: '🛡️',
      description: 'Won 10 battles',
      condition: 'Win 10 live battles',
    ),
    BadgeModel(
      id: 'top_performer',
      name: 'Top Performer',
      emoji: '🌟',
      description: 'Ranked #1 on any leaderboard',
      condition: 'Reach rank #1 on any leaderboard',
    ),
    BadgeModel(
      id: 'tournament_winner',
      name: 'Tournament Champion',
      emoji: '🥇',
      description: 'Won a tournament',
      condition: 'Win a tournament',
    ),
    BadgeModel(
      id: 'level_10',
      name: 'Explorer',
      emoji: '🗺️',
      description: 'Reached level 10',
      condition: 'Reach level 10',
    ),
    BadgeModel(
      id: 'level_20',
      name: 'Challenger',
      emoji: '🎖️',
      description: 'Reached level 20',
      condition: 'Reach level 20',
    ),
  ];

  static BadgeModel? findById(String id) {
    try {
      return all.firstWhere((b) => b.id == id);
    } catch (_) {
      return null;
    }
  }
}
