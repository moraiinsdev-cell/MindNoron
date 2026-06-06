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
    final sound = AmbientSound.fromName(
        ref.watch(ambientSoundProvider).valueOrNull ?? 'rain');
    final volume = ref.watch(ambientVolumeProvider).valueOrNull ??
        AppConstants.defaultAmbientVolume;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FilledButton.tonalIcon(
          onPressed: () {
            if (_playing) {
              svc.stopAmbient();
            } else {
              svc.startAmbient(sound, volume: volume);
            }
            setState(() => _playing = !_playing);
          },
          icon: Icon(_playing ? Icons.stop : Icons.play_arrow),
          label: Text(_playing ? 'Stop ${sound.label}' : 'Play ${sound.label}'),
        ),
        const SizedBox(width: 8),
        PopupMenuButton<AmbientSound>(
          tooltip: 'Change soundscape',
          icon: const Icon(Icons.graphic_eq),
          initialValue: sound,
          itemBuilder: (_) => [
            for (final s in AmbientSound.choices)
              PopupMenuItem(value: s, child: Text(s.label)),
          ],
          onSelected: (s) {
            settings.setAmbientSound(s.name);
            if (_playing) svc.startAmbient(s, volume: volume);
          },
        ),
      ],
    );
  }
}
