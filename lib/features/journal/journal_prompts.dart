/// Gentle daily reflection prompts. One is chosen per calendar day so the
/// prompt feels intentional, not random on every rebuild.
const journalPrompts = <String>[
  'What went well today?',
  'What is one thing you are grateful for?',
  'What drained your energy, and what restored it?',
  'What did you learn today?',
  'What is weighing on your mind right now?',
  'What would make tomorrow a good day?',
  'When did you feel most focused today?',
  'What is one small win you can celebrate?',
  'What did you avoid, and why?',
  'Who or what are you thankful for today?',
  'What is the kindest thing you did today?',
  'If today had a title, what would it be?',
  'What are you looking forward to?',
  'What is something you can let go of?',
];

/// Stable prompt for [date] — same all day, rotates day to day.
String promptForDate(DateTime date) {
  final dayNumber =
      DateTime(date.year, date.month, date.day).millisecondsSinceEpoch ~/
          Duration.millisecondsPerDay;
  return journalPrompts[dayNumber % journalPrompts.length];
}
