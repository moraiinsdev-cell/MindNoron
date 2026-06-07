import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/platform/sound_service.dart';
import '../../core/providers/app_providers.dart';
import '../../data/repositories/settings_repository.dart';

/// A compact play/stop + soundscape picker for the active session, so the user
/// can start a focus bed without diving into settings. Reflects the bed that
/// may already be auto-playing.
class AmbientControl extends ConsumerStatefulWidget {
  const AmbientControl({super.key});

  @override
  ConsumerState<AmbientControl> createState() => _AmbientControlState();
}

class _AmbientControlState extends ConsumerState<AmbientControl> {
  late bool _playing = ref.read(soundServiceProvider).ambientPlaying;

  @override
  Widget build(BuildContext context) {
    final settings = ref.read(settingsRepositoryProvider);
    final svc = ref.read(soundServiceProvider);
    final id = ref.watch(ambientSoundProvider).valueOrNull ?? 'rain';
    final tracks = ref.watch(customTracksProvider).valueOrNull ?? const [];
    final volume = ref.watch(ambientVolumeProvider).valueOrNull ??
        AppConstants.defaultAmbientVolume;
    final label = _labelFor(id, tracks);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FilledButton.tonalIcon(
          onPressed: () {
            if (_playing) {
              svc.stopAmbient();
            } else {
              svc.startAmbientId(id, volume: volume);
            }
            setState(() => _playing = !_playing);
          },
          icon: Icon(_playing ? Icons.stop : Icons.play_arrow),
          label: Text(_playing ? 'Stop $label' : 'Play $label'),
        ),
        const SizedBox(width: 8),
        PopupMenuButton<String>(
          tooltip: 'Change soundscape',
          icon: const Icon(Icons.graphic_eq),
          initialValue: id,
          itemBuilder: (_) => [
            for (final s in AmbientSound.choices)
              PopupMenuItem(value: s.name, child: Text(s.label)),
            if (tracks.isNotEmpty) const PopupMenuDivider(),
            for (final t in tracks)
              PopupMenuItem(value: t.id, child: Text(t.name)),
          ],
          onSelected: (selectedId) {
            settings.setAmbientSound(selectedId);
            if (_playing) svc.startAmbientId(selectedId, volume: volume);
          },
        ),
      ],
    );
  }

  /// Display label for the current selection id (built-in name or custom id).
  static String _labelFor(String id, List<CustomTrack> tracks) {
    if (id.startsWith(SoundService.customPrefix)) {
      return tracks
          .firstWhere(
            (t) => t.id == id,
            orElse: () => const CustomTrack(path: '', name: 'Custom track'),
          )
          .name;
    }
    return AmbientSound.fromName(id).label;
  }
}
