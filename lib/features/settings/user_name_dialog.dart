import 'package:flutter/material.dart';

Future<String?> showUserNameDialog(
  BuildContext context, {
  String? currentName,
  bool firstRun = false,
}) {
  final controller = TextEditingController(text: currentName ?? '');

  return showDialog<String?>(
    context: context,
    barrierDismissible: !firstRun,
    builder: (context) {
      void save() => Navigator.pop(context, controller.text.trim());

      return AlertDialog(
        title: Text(firstRun ? 'What should I call you?' : 'Your name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 40,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            labelText: 'Name',
            hintText: 'Alex',
          ),
          onSubmitted: (_) => save(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(firstRun ? 'Later' : 'Cancel'),
          ),
          FilledButton(
            onPressed: save,
            child: const Text('Save'),
          ),
        ],
      );
    },
  ).whenComplete(controller.dispose);
}
