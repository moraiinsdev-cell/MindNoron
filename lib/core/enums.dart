import 'package:flutter/material.dart';

/// Lifecycle of a [Task]. Stored as a short string in the DB.
enum TaskStatus {
  todo,
  inProgress,
  done,
  archived;

  String get db => switch (this) {
        TaskStatus.todo => 'todo',
        TaskStatus.inProgress => 'in_progress',
        TaskStatus.done => 'done',
        TaskStatus.archived => 'archived',
      };

  static TaskStatus fromDb(String s) => switch (s) {
        'in_progress' => TaskStatus.inProgress,
        'done' => TaskStatus.done,
        'archived' => TaskStatus.archived,
        _ => TaskStatus.todo,
      };

  /// Human label shown on the task status control.
  String get label => switch (this) {
        TaskStatus.todo => 'Pending',
        TaskStatus.inProgress => 'In progress',
        TaskStatus.done => 'Finished',
        TaskStatus.archived => 'Archived',
      };

  IconData get icon => switch (this) {
        TaskStatus.todo => Icons.radio_button_unchecked,
        TaskStatus.inProgress => Icons.timelapse,
        TaskStatus.done => Icons.check_circle,
        TaskStatus.archived => Icons.inventory_2_outlined,
      };

  Color color(ColorScheme cs) => switch (this) {
        TaskStatus.inProgress => const Color(0xFF3B82F6), // blue
        TaskStatus.done => const Color(0xFF22C55E), // green
        _ => cs.onSurfaceVariant,
      };

  /// The three states a user can pick from the status control.
  static const selectable = [
    TaskStatus.todo,
    TaskStatus.inProgress,
    TaskStatus.done,
  ];
}

/// Kind of focus session.
enum SessionType {
  work,
  shortBreak,
  longBreak;

  String get db => switch (this) {
        SessionType.work => 'work',
        SessionType.shortBreak => 'short_break',
        SessionType.longBreak => 'long_break',
      };

  static SessionType fromDb(String s) => switch (s) {
        'short_break' => SessionType.shortBreak,
        'long_break' => SessionType.longBreak,
        _ => SessionType.work,
      };

  String get label => switch (this) {
        SessionType.work => 'Focus',
        SessionType.shortBreak => 'Short break',
        SessionType.longBreak => 'Long break',
      };
}

/// Task priority helpers. 1 = highest … 4 = lowest.
abstract final class Priority {
  static const int highest = 1;
  static const int high = 2;
  static const int normal = 3;
  static const int low = 4;

  static Color color(int p, ColorScheme cs) => switch (p) {
        1 => const Color(0xFFEF4444), // red
        2 => const Color(0xFFF59E0B), // amber
        3 => cs.primary,
        _ => cs.outline,
      };

  static String label(int p) => 'P$p';
}
