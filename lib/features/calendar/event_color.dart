import 'package:flutter/material.dart';

/// Colour labels for calendar events (Google-Calendar style). Stored by [name].
enum EventColor {
  blue('Blue', Color(0xFF3B82F6)),
  teal('Teal', Color(0xFF14B8A6)),
  green('Green', Color(0xFF22C55E)),
  amber('Amber', Color(0xFFF59E0B)),
  orange('Orange', Color(0xFFF97316)),
  red('Red', Color(0xFFEF4444)),
  purple('Purple', Color(0xFF8B5CF6)),
  pink('Pink', Color(0xFFEC4899));

  const EventColor(this.label, this.color);

  final String label;
  final Color color;

  static EventColor fromName(String? name) => values.firstWhere(
        (c) => c.name == name,
        orElse: () => EventColor.blue,
      );
}
