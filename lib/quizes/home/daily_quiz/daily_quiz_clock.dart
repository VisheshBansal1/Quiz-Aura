/// Single source of truth for "which day is it" in the Daily Quiz feature.
///
/// The Daily Quiz rolls over at 12:00 AM **India Standard Time (UTC+05:30)**.
/// India has no daylight saving, so a fixed offset is always correct.
/// This MUST match the generator in `daily_quiz_automation/` (same offset),
/// otherwise the app and the generator would disagree about the quiz id.
///
/// To run the quiz on another timezone, change [offset] here and
/// `IST_OFFSET_MINUTES` in `generate-daily-quiz.mjs`.
class DailyQuizClock {
  DailyQuizClock._();

  static const Duration offset = Duration(hours: 5, minutes: 30);

  /// "Wall clock" in IST, stored in a UTC DateTime (only the y/m/d/h/m/s
  /// fields are meaningful).
  static DateTime _istWallClock([DateTime? now]) =>
      (now ?? DateTime.now()).toUtc().add(offset);

  /// Firestore document id of today's quiz, e.g. `2026-11-04`.
  static String todayId([DateTime? now]) {
    final d = _istWallClock(now);
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  /// The real instant of the next 12:00 AM IST.
  static DateTime nextMidnight([DateTime? now]) {
    final d = _istWallClock(now);
    return DateTime.utc(d.year, d.month, d.day + 1).subtract(offset);
  }

  static Duration untilNextMidnight([DateTime? now]) {
    final diff = nextMidnight(now).difference((now ?? DateTime.now()).toUtc());
    return diff.isNegative ? Duration.zero : diff;
  }

  /// `07h 05m 09s`
  static String formatCountdown(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.inHours)}h ${two(d.inMinutes.remainder(60))}m '
        '${two(d.inSeconds.remainder(60))}s';
  }
}
