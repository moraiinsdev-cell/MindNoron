/// Date helpers shared across MindNoron.
class AppDateUtils {
  AppDateUtils._();

  /// Midnight of the given day (used as the canonical key for [DailyLog]).
  static DateTime startOfDay(DateTime dt) =>
      DateTime(dt.year, dt.month, dt.day);

  /// Last moment of the given day.
  static DateTime endOfDay(DateTime dt) =>
      DateTime(dt.year, dt.month, dt.day, 23, 59, 59, 999);

  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static bool isToday(DateTime dt) => isSameDay(dt, DateTime.now());

  /// Inclusive range [start, end] for the next [days] days from today.
  static (DateTime, DateTime) upcomingRange(int days) {
    final now = DateTime.now();
    return (startOfDay(now), endOfDay(now.add(Duration(days: days))));
  }
}
