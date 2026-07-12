import 'package:flutter/material.dart';

Future<String?> showUserNameDialog(
  BuildContext context, {
  String? currentName,
  bool firstRun = false,
}) {
  return showDialog<String?>(
    context: context,
    barrierDismissible: !firstRun,
    builder: (context) => _UserNameDialog(
      currentName: currentName,
      firstRun: firstRun,
    ),
  );
}

/// Owns its own [TextEditingController] so the controller is disposed only after
/// the dialog is fully removed (in [State.dispose]). Disposing it the instant
/// the route pops — as a `.whenComplete()` callback would — crashes on the
/// dialog's exit animation, which still reads the controller. The hardware Back
/// button on Android reliably triggers that path.
class _UserNameDialog extends StatefulWidget {
  const _UserNameDialog({this.currentName, required this.firstRun});

  final String? currentName;
  final bool firstRun;

  @override
  State<_UserNameDialog> createState() => _UserNameDialogState();
}

class _UserNameDialogState extends State<_UserNameDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.currentName ?? '');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() => Navigator.pop(context, _controller.text.trim());

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.firstRun ? 'What should I call you?' : 'Your name'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: 40,
        textInputAction: TextInputAction.done,
        decoration: const InputDecoration(
          labelText: 'Name',
          hintText: 'Alex',
        ),
        onSubmitted: (_) => _save(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(widget.firstRun ? 'Later' : 'Cancel'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
