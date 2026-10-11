// lib/services/global_music_service.dart
// Persipal Virtual Pet background music.
// The BGM is active only while the user is inside the Virtual Pet module.
// One player is reused so Game/Feed/Play/Groom share the same track.

import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';

import 'local_storage_service.dart';
import '../utils/nighttime_mode.dart';
import '../utils/day_period.dart';

class GlobalMusicService with WidgetsBindingObserver {
  GlobalMusicService._();
  static final GlobalMusicService instance = GlobalMusicService._();

  final AudioPlayer _player = AudioPlayer();
  // Short one-shot SFX must not interrupt long-running grooming-tool sounds.
  final AudioPlayer _sfxPlayer = AudioPlayer();
  final AudioPlayer _toolSfxPlayer = AudioPlayer();

  bool _started = false;
  bool _enabled = true;
  bool _virtualPetActive = false;
  bool _appInBackground = false;
  bool _nightMusicActive = false;
  String? _loopingSfxFilename;
  int _toolSfxRequestId = 0;

  Future<void> init() async {
    if (!_started) {
      WidgetsBinding.instance.addObserver(this);
    } else {
      return;
    }

    try {
      _enabled =
          (await LocalStorageService.instance.fetchSettings()).soundEnabled;

      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.setVolume(0.25);
      // Pre-load the BGM source once so returning from background can resume
      // without reloading bg.mp3 from the asset bundle.
      await _setMusicForCurrentTime();
      _started = true;
      dayPeriodNotifier.addListener(_onDayPeriodChanged);
    } catch (e) {
      debugPrint('GlobalMusicService: init failed: $e');
    }
  }

  /// Starts BGM when the user enters the Virtual Pet module.
  ///
  /// IMPORTANT: _virtualPetActive is set before init(), so the first entry
  /// into Virtual Pet also starts the music. The previous implementation
  /// initialized the player and returned before actually playing the track.
  Future<void> startForVirtualPet() async {
    _virtualPetActive = true;

    try {
      await init();

      if (_enabled && !_appInBackground) {
        await _playIfNeeded();
      }
    } catch (e) {
      debugPrint('GlobalMusicService: virtual pet start failed: $e');
    }
  }

  /// Stops BGM when leaving the Virtual Pet module.
  Future<void> stopForVirtualPet() async {
    _virtualPetActive = false;

    try {
      if (_started) {
        await _player.stop();
        await stopLoopingSfx();
        await stopSfx();
      }
    } catch (e) {
      debugPrint('GlobalMusicService: virtual pet stop failed: $e');
    }
  }

  /// Settings -> Sound.
  ///
  /// Turning Sound on outside Virtual Pet must NOT start the BGM.
  /// Turning it on inside Virtual Pet resumes/starts the BGM.
  Future<void> setEnabled(bool enabled) async {
    _enabled = enabled;

    if (!_started) return;

    try {
      if (enabled && _virtualPetActive && !_appInBackground) {
        await _playIfNeeded();
      } else {
        await _player.stop();
      }
    } catch (e) {
      debugPrint('GlobalMusicService: toggle failed: $e');
    }
  }

  void _onDayPeriodChanged() {
    // DayPeriod changes at the exact 6:00 PM boundary, so the BGM switches
    // immediately without waiting for a polling interval.
    unawaited(_setMusicForCurrentTime());
  }

  Future<void> _setMusicForCurrentTime() async {
    if (!_started && _virtualPetActive == false) return;

    final shouldUseNightMusic = NighttimeMode.isNighttime();
    if (shouldUseNightMusic == _nightMusicActive && _started) return;

    _nightMusicActive = shouldUseNightMusic;

    try {
      await _player.setSource(
        AssetSource(
          shouldUseNightMusic ? 'sounds/night.mp3' : 'sounds/bg.mp3',
        ),
      );

      if (_virtualPetActive && _enabled && !_appInBackground) {
        await _player.setReleaseMode(ReleaseMode.loop);
        await _player.play(
          AssetSource(
            shouldUseNightMusic ? 'sounds/night.mp3' : 'sounds/bg.mp3',
          ),
          volume: 0.25,
        );
      }
    } catch (e) {
      debugPrint('GlobalMusicService: music switch failed: $e');
    }
  }

  Future<void> _playIfNeeded() async {
    if (!_enabled || !_virtualPetActive || _appInBackground) return;

    try {
      final shouldUseNightMusic = NighttimeMode.isNighttime();
      final filename =
          shouldUseNightMusic ? 'sounds/night.mp3' : 'sounds/bg.mp3';
      if (_nightMusicActive != shouldUseNightMusic) {
        _nightMusicActive = shouldUseNightMusic;
      }

      if (_player.state == PlayerState.playing) return;
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.play(AssetSource(filename), volume: 0.25);
    } catch (e) {
      debugPrint('GlobalMusicService: play failed: $e');
    }
  }

  /// Starts a looping tool sound while a grooming item is being dragged.
  /// A dedicated player prevents water/animation one-shot SFX from interrupting it.
  Future<void> startLoopingSfx(String filename) async {
    if (!_virtualPetActive || !_enabled || _appInBackground) return;

    final requestId = ++_toolSfxRequestId;
    _loopingSfxFilename = filename;

    try {
      await init();
      if (requestId != _toolSfxRequestId ||
          _loopingSfxFilename != filename ||
          !_virtualPetActive ||
          !_enabled ||
          _appInBackground) {
        return;
      }

      await _toolSfxPlayer.stop();
      if (requestId != _toolSfxRequestId ||
          _loopingSfxFilename != filename ||
          !_virtualPetActive ||
          !_enabled ||
          _appInBackground) {
        return;
      }

      await _toolSfxPlayer.setReleaseMode(ReleaseMode.loop);
      await _toolSfxPlayer.setVolume(1.0);
      await _toolSfxPlayer.play(
        AssetSource('sounds/$filename'),
        volume: 1.0,
      );
    } catch (e) {
      debugPrint('GlobalMusicService: looping tool SFX failed ($filename): $e');
    }
  }

  /// Stops only the active grooming-tool loop on release/cancel.
  Future<void> stopLoopingSfx() async {
    ++_toolSfxRequestId;
    _loopingSfxFilename = null;
    try {
      await _toolSfxPlayer.stop();
      await _toolSfxPlayer.setReleaseMode(ReleaseMode.release);
    } catch (e) {
      debugPrint('GlobalMusicService: stopping tool SFX failed: $e');
    }
  }

  /// Stops the current one-shot effect when leaving a screen or changing state.
  Future<void> stopSfx() async {
    try {
      await _sfxPlayer.stop();
      await _sfxPlayer.setReleaseMode(ReleaseMode.release);
    } catch (e) {
      debugPrint('GlobalMusicService: stopping SFX failed: $e');
    }
  }

  /// Plays a short Virtual Pet sound effect.
  ///
  /// SFX uses a separate player so it never interrupts the looping BGM.
  /// Sound is only audible while the user is inside Virtual Pet and the
  /// Settings -> Sound toggle is enabled.
  Future<void> playSfx(String filename) async {
    if (!_virtualPetActive || !_enabled || _appInBackground) return;

    try {
      await init();
      if (!_virtualPetActive || !_enabled || _appInBackground) return;

      await _sfxPlayer.setReleaseMode(ReleaseMode.release);
      await _sfxPlayer.play(
        AssetSource('sounds/$filename'),
      );
    } catch (e) {
      debugPrint('GlobalMusicService: SFX failed ($filename): $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final isBackgrounded = state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached;

    if (isBackgrounded) {
      _appInBackground = true;
      // Stop instead of pause so the native audio session cannot continue
      // output while iOS/Android moves the app out of the foreground.
      unawaited(_stopForBackground());
    } else if (state == AppLifecycleState.resumed) {
      _appInBackground = false;
      // Re-evaluate local time first in case the app was backgrounded across
      // 6:00 PM or 6:00 AM, then ensure the correct track is playing.
      unawaited(_refreshMusicAfterResume());
    }
  }

  Future<void> _refreshMusicAfterResume() async {
    await _setMusicForCurrentTime();
    if (_virtualPetActive && _enabled && !_appInBackground) {
      await _playIfNeeded();
    }
  }

  Future<void> _stopForBackground() async {
    try {
      await _player.stop();
      await stopLoopingSfx();
      await _sfxPlayer.stop();
      await _sfxPlayer.setReleaseMode(ReleaseMode.release);
    } catch (e) {
      debugPrint('GlobalMusicService: background audio stop failed: $e');
    }
  }

  Future<void> dispose() async {
    dayPeriodNotifier.removeListener(_onDayPeriodChanged);
    WidgetsBinding.instance.removeObserver(this);
    await _player.dispose();
    await _sfxPlayer.dispose();
    await _toolSfxPlayer.dispose();
  }
}
