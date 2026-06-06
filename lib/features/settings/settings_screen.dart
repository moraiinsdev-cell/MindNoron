import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../data/backup/backup_service.dart';
import '../../data/repositories/settings_repository.dart';
import '../../l10n/app_localizations.dart';
import '../../presentation/widgets/common/section_scaffold.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  Future<void> _backupNow() async {
    final messenger = ScaffoldMessenger.of(context);
    final file = await ref.read(backupServiceProvider).backupNow();
    if (!mounted) return;
    messenger.showSnackBar(SnackBar(content: Text('Backed up: ${file.path}')));
  }

  Future<void> _export() async {
    final messenger = ScaffoldMessenger.of(context);
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Export MindNoron data',
      fileName: 'mindnoron-backup.json',
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (path == null) return;
    await ref.read(backupServiceProvider).exportTo(path);
    if (!mounted) return;
    messenger.showSnackBar(const SnackBar(content: Text('Export complete')));
  }

  Future<void> _import() async {
    final messenger = ScaffoldMessenger.of(context);
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    final path = result?.files.single.path;
    if (path == null) return;
    await ref.read(backupServiceProvider).importFrom(path);
    if (!mounted) return;
    messenger.showSnackBar(const SnackBar(content: Text('Data restored')));
  }

  Future<void> _clearAll() async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete all data?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete all'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(backupServiceProvider).clearAll();
    if (!mounted) return;
    messenger.showSnackBar(const SnackBar(content: Text('All data deleted')));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final settings = ref.read(settingsRepositoryProvider);
    final mode = ref.watch(themeModeProvider).valueOrNull ?? ThemeMode.dark;
    final work = ref.watch(workMinutesProvider).valueOrNull ??
        AppConstants.defaultWorkMinutes;
    final shortBreak = ref.watch(shortBreakMinutesProvider).valueOrNull ??
        AppConstants.defaultShortBreakMinutes;
    final longBreak = ref.watch(longBreakMinutesProvider).valueOrNull ??
        AppConstants.defaultLongBreakMinutes;

    return SectionScaffold(
      title: l10n.navSettings,
      child: ListView(
        children: [
          _SectionCard(
            title: 'Appearance',
            child: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(value: ThemeMode.system, label: Text('System')),
                ButtonSegment(value: ThemeMode.light, label: Text('Light')),
                ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
              ],
              selected: {mode},
              onSelectionChanged: (s) => settings.setThemeMode(s.first),
            ),
          ),
          _SectionCard(
            title: 'Pomodoro (minutes)',
            child: Column(
              children: [
                _StepperRow(
                  label: 'Focus',
                  value: work,
                  onChanged: (v) => settings.setWorkMinutes(v),
                ),
                _StepperRow(
                  label: 'Short break',
                  value: shortBreak,
                  onChanged: (v) => settings.setShortBreakMinutes(v),
                ),
                _StepperRow(
                  label: 'Long break',
                  value: longBreak,
                  onChanged: (v) => settings.setLongBreakMinutes(v),
                ),
              ],
            ),
          ),
          const _SectionCard(
            title: 'Shortcuts',
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.keyboard_command_key),
              title: Text('Global quick capture'),
              trailing: Text(AppConstants.defaultCaptureHotkey),
            ),
          ),
          _SectionCard(
            title: 'Data',
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.tonalIcon(
                  onPressed: _backupNow,
                  icon: const Icon(Icons.backup_outlined),
                  label: const Text('Back up now'),
                ),
                FilledButton.tonalIcon(
                  onPressed: _export,
                  icon: const Icon(Icons.file_download_outlined),
                  label: const Text('Export JSON...'),
                ),
                FilledButton.tonalIcon(
                  onPressed: _import,
                  icon: const Icon(Icons.file_upload_outlined),
                  label: const Text('Restore...'),
                ),
                OutlinedButton.icon(
                  onPressed: _clearAll,
                  icon: const Icon(Icons.delete_forever_outlined),
                  label: const Text('Delete all data'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class _StepperRow extends StatelessWidget {
  const _StepperRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          IconButton.outlined(
            icon: const Icon(Icons.remove),
            onPressed: () => onChanged((value - 5).clamp(5, 120)),
          ),
          SizedBox(
            width: 44,
            child: Text('$value', textAlign: TextAlign.center),
          ),
          IconButton.outlined(
            icon: const Icon(Icons.add),
            onPressed: () => onChanged((value + 5).clamp(5, 120)),
          ),
        ],
      ),
    );
  }
}
