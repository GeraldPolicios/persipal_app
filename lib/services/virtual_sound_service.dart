// lib/services/virtual_sound_service.dart
//
// Short sound effects for the VIRTUAL CAT SIMULATION only — feeding,
// grooming and playing. Nothing else in the app plays audio.
//
// The simulation code itself is untouched: main.dart forwards
// VirtualPetProvider's already-public action counters here (the same way it
// feeds VirtualAchievementService), and a sound plays when a counter goes up
// by exactly one — a real feed/groom/play action, never a decay tick, a
// cloud restore or app start-up. Those counters only change inside the
// simulation screens, so the sounds can only be heard there.
//
// Controlled by Settings › Sound Effects (AppSettings.soundEnabled, persisted
// in Hive). The effects are short original clips in assets/sounds/.

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import '../models/virtual_pet_state.dart';
import 'local_storage_service.dart';

class VirtualSoundService {
  VirtualSoundService._();
  static final VirtualSoundService instance = VirtualSoundService._();

  AudioPlayer? _player;
  int? _feed, _groom, _play; // null until the baseline is taken

  /// Called by main.dart on each VirtualPetProvider change (once loaded).
  void onVirtualPetChanged(VirtualPetState pet) {
    final lastFeed = _feed, lastGroom = _groom, lastPlay = _play;
    _feed = pet.simFeedCount;
    _groom = pet.simGroomCount;
    _play = pet.simPlayCount;
    if (lastFeed == null || lastGroom == null || lastPlay == null) return;

    if (pet.simFeedCount == lastFeed + 1) {
      _play_('feed');
    } else if (pet.simGroomCount == lastGroom + 1) {
      _play_('groom');
    } else if (pet.simPlayCount == lastPlay + 1) {
      _play_('play');
    }
  }

  Future<void> _play_(String effect) async {
    try {
      final enabled = (await LocalStorageService.instance.fetchSettings())
          .soundEnabled;
      if (!enabled) return;
      final player = _player ??= AudioPlayer()..setReleaseMode(ReleaseMode.stop);
      await player.stop();
      await player.play(AssetSource('sounds/$effect.wav'), volume: 0.6);
    } catch (e) {
      // Audio must never affect gameplay.
      debugPrint('VirtualSoundService: could not play $effect: $e');
    }
  }
}
