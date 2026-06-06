import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A compact icon button that copies [text] to the clipboard and shows a brief
/// "Copied" confirmation. Reused anywhere text should be easy to grab.
class CopyIconButton extends StatelessWidget {
  const CopyIconButton({
    super.key,
    required this.text,
    this.tooltip = 'Copy text',
    this.size = 18,
  });

  final String text;
  final String tooltip;
  final double size;

  Future<void> _copy(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: text));
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard'),
        duration: Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      iconSize: size,
      icon: const Icon(Icons.copy_outlined),
      onPressed: text.trim().isEmpty ? null : () => _copy(context),
    );
  }
}
