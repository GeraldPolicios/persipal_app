import 'dart:async';

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../models/pet_state.dart';

class CatAnimation extends FlameGame {
  late SpriteAnimationComponent cat;

  late SpriteAnimation sleepAnimation;
  late SpriteAnimation wakeAnimation;
  late SpriteAnimation stretchAnimation;
  late SpriteAnimation lookAnimation;
  late SpriteAnimation sitAnimation;
  late SpriteAnimation idleAnimation;

  // ── Mood-reactive animations ──────────────────────────────────────────
  // Reused as-is from existing project assets (see cat_animation.dart's
  // onLoad below for exactly which files) — no new art was created.
  late SpriteAnimation happyAnimation;
  late SpriteAnimation sadAnimation; // used for the "hungry" mood
  late SpriteAnimation angryAnimation;
  late SpriteAnimation dirtyAnimation;
  late SpriteAnimation neglectedAnimation;

  bool _isWaking = false;

  // True once the initial Sleep → Wake → Stretch → Look → Sit → Idle
  // sequence has finished at least once. Distinguishes "the cat's very
  // first wake-up" (should play the full sequence) from "the cat is
  // already awake and idle" (a later tap should just get a quick
  // reaction, not a disruptive full replay).
  bool _hasWokenUp = false;

  // Guards reactToTap() the same way _isWaking guards wakeUp(): prevents a
  // second reaction from stacking on top of one that's still playing.
  bool _reacting = false;

  bool _loaded = false;
  final Completer<void> _readyCompleter = Completer<void>();

  /// Completes once onLoad() has finished loading every sprite/animation
  /// and `cat` exists. Callers (GameScreen) await this once so they can
  /// force a single rebuild right after Flame is actually ready, instead
  /// of guessing at timing — see setMood()'s own _loaded guard below for
  /// why that matters. (Named catReady, not ready — FlameGame already
  /// defines its own `ready`.)
  Future<void> get catReady => _readyCompleter.future;

  /// The mood actually showing on `cat.animation` right now. Only ever
  /// written by [_applyDesiredMood] (the single place allowed to change
  /// cat.animation for a mood), so it can never drift from reality.
  PetState _appliedMood = PetState.idle;

  /// The latest mood GameScreen has asked for via [setMood] — recorded
  /// every call, even when it can't be shown immediately (still asleep, or
  /// a wake/tap reaction is mid-flight). [_applyDesiredMood] is what
  /// actually turns this into a visible change, and is re-run once
  /// wakeUp()/reactToTap() finish, so the most recently requested mood is
  /// never silently dropped.
  PetState _desiredMood = PetState.idle;

  @override
  Color backgroundColor() => Colors.transparent;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Load sleep sprite sheet
    final sleepSheet = await images.load(
      'cat_parts/sleep/sleepsprite.png',
    );

    // Sleep animation
    sleepAnimation = SpriteAnimation.fromFrameData(
      sleepSheet,
      SpriteAnimationData.sequenced(
        // 121 sleep frames
        amount: 121,

        // Smooth 24 fps
        stepTime: 0.0417,

        // Each frame is 96 x 96
        textureSize: Vector2(96, 96),

        // 11 frames per row
        amountPerRow: 11,

        // Keep sleeping
        loop: true,
      ),
    );

    // Load wake sprite sheet
    final wakeSheet = await images.load(
      'cat_parts/wake/wakesprite.png',
    );

    // Wake animation
    wakeAnimation = SpriteAnimation.fromFrameData(
      wakeSheet,
      SpriteAnimationData.sequenced(
        // 60 wake frames
        amount: 60,

        // 60 x 0.08 = 4.8 seconds
        stepTime: 0.08,

        // Each frame is 96 x 96
        textureSize: Vector2(96, 96),

        // 20 frames per row
        amountPerRow: 20,

        // Play once
        loop: false,
      ),
    );

    // Load stretch sprite sheet
    final stretchSheet = await images.load(
      'cat_parts/stretch/stretchsheet.png',
    );

    // Stretch animation
    stretchAnimation = SpriteAnimation.fromFrameData(
      stretchSheet,
      SpriteAnimationData.sequenced(
        // 60 stretch frames
        amount: 60,

        // 60 x 0.06 = 3.6 seconds
        stepTime: 0.06,

        // Each frame is 96 x 96
        textureSize: Vector2(96, 96),

        // 20 frames per row
        amountPerRow: 20,

        // Play once
        loop: false,
      ),
    );

    // Load look sprite sheet
    final lookSheet = await images.load(
      'cat_parts/look/looksheet.png',
    );

    // Look left and right animation
    lookAnimation = SpriteAnimation.fromFrameData(
      lookSheet,
      SpriteAnimationData.sequenced(
        // 60 look frames
        amount: 60,

        // 60 x 0.06 = 3.6 seconds
        stepTime: 0.06,

        // Each frame is 96 x 96
        textureSize: Vector2(96, 96),

        // 20 frames per row
        amountPerRow: 20,

        // Play once
        loop: false,
      ),
    );

    // Load sit sprite sheet
    final sitSheet = await images.load(
      'cat_parts/sit/sitsheet.png',
    );

    // Sit animation
    sitAnimation = SpriteAnimation.fromFrameData(
      sitSheet,
      SpriteAnimationData.sequenced(
        // 60 sit frames
        amount: 60,

        // 60 x 0.06 = 3.6 seconds
        stepTime: 0.06,

        // Each frame is 96 x 96
        textureSize: Vector2(96, 96),

        // 20 frames per row
        amountPerRow: 20,

        // Play once
        loop: false,
      ),
    );

    // Load idle sprite sheet
    final idleSheet = await images.load(
      'cat_parts/idle/idlesheet.png',
    );

    // Idle animation
    idleAnimation = SpriteAnimation.fromFrameData(
      idleSheet,
      SpriteAnimationData.sequenced(
        // 60 idle frames
        amount: 60,

        // Smooth 24 fps
        stepTime: 0.06,

        // Each frame is 96 x 96
        textureSize: Vector2(96, 96),

        // 20 frames per row
        amountPerRow: 20,

        // Keep idle animation looping
        loop: true,
      ),
    );

    // Mood-reactive animations. Loaded once here, alongside the sprite
    // sheets above, so runtime mood switches (setMood) are instant.
    happyAnimation = await _loadFrameSequence('happy_cat', 'happy_', 31);
    sadAnimation = await _loadFrameSequence('sad_cat', 'sad_', 121);
    angryAnimation = await _loadStaticFrame('states/angry_cat.png');
    dirtyAnimation = await _loadStaticFrame('states/dirty_cat.png');
    neglectedAnimation = await _loadStaticFrame('states/dirty_cat1.png');

    // Create cat
    cat = SpriteAnimationComponent(
      // Start with sleeping animation
      animation: sleepAnimation,

      // Keep the same size as one sprite frame
      size: Vector2(96, 96),

      // Center the cat
      anchor: Anchor.center,

      // Keep the cat in one fixed position
      position: Vector2(
        size.x / 2,
        size.y - 45,
      ),
    );

    add(cat);

    _loaded = true;
    _readyCompleter.complete();
  }

  /// Loads a mood animation made of individually-numbered frame files
  /// (e.g. assets/images/happy_cat/happy_0001.png ...) — the same format
  /// already used elsewhere in the project (idle/, sad_cat/, happy_cat/,
  /// play_cat/*), as opposed to the single sprite-sheet PNGs used by the
  /// wake-up sequence above.
  Future<SpriteAnimation> _loadFrameSequence(
    String folder,
    String prefix,
    int count, {
    double stepTime = 0.05,
  }) async {
    final sprites = <Sprite>[];

    for (var i = 1; i <= count; i++) {
      final image = await images.load(
        '$folder/$prefix${i.toString().padLeft(4, '0')}.png',
      );

      sprites.add(Sprite(image));
    }

    return SpriteAnimation.spriteList(sprites, stepTime: stepTime);
  }

  /// Wraps a single existing static mood PNG (no dedicated animated
  /// sequence exists for this mood — see the Mood Integration report) in
  /// a one-frame SpriteAnimation, so it can be assigned to `cat.animation`
  /// exactly like every other mood without a second component type.
  Future<SpriteAnimation> _loadStaticFrame(String path) async {
    final image = await images.load(path);
    return SpriteAnimation.spriteList([Sprite(image)], stepTime: 1);
  }

  // Sleep -> Wake -> Stretch -> Look -> Sit -> Idle
  //
  // While this sequence is running, setMood() (see below) deliberately
  // cannot touch cat.animation — it only records the latest requested
  // mood in _desiredMood. Once the sequence genuinely finishes, this
  // method applies _desiredMood itself (exactly once), so a mood that was
  // requested while the cat was asleep/waking is never lost, and the cat
  // wakes into whatever its real current mood actually is instead of
  // always forcing idle.
  //
  // `if (!cat.isMounted) return;` before each step is the minimal guard
  // against continuing this ~16s async sequence after the component has
  // been removed (e.g. GameScreen disposed mid-wake) — it only stops
  // further writes to a torn-down component, nothing else changes.
  Future<void> wakeUp() async {
    // Prevent the sequence from starting again
    if (_isWaking) return;

    _isWaking = true;

    if (!cat.isMounted) return;
    // Sleep -> Wake
    cat.animation = wakeAnimation;

    // Wait for Wake to finish
    await Future.delayed(
      const Duration(milliseconds: 4800),
    );

    if (!cat.isMounted) return;
    // Wake -> Stretch
    cat.animation = stretchAnimation;

    // Wait for Stretch to finish
    await Future.delayed(
      const Duration(milliseconds: 3600),
    );

    if (!cat.isMounted) return;
    // Stretch -> Look
    cat.animation = lookAnimation;

    // Wait for Look to finish
    await Future.delayed(
      const Duration(milliseconds: 3600),
    );

    if (!cat.isMounted) return;
    // Look -> Sit
    cat.animation = sitAnimation;

    // Wait for Sit to finish
    await Future.delayed(
      const Duration(milliseconds: 3600),
    );

    if (!cat.isMounted) return;

    // Sequence genuinely finished — the cat is awake now.
    _isWaking = false;
    _hasWokenUp = true;

    // Sit -> whatever the real current mood actually is (idle if nothing
    // else was ever requested — _desiredMood starts at idle). Forced: at
    // this exact point cat.animation is still showing sitAnimation
    // (single-play, non-looping), NOT _appliedMood's animation — its
    // default `idle` value is just an unapplied bookkeeping sentinel, so
    // the normal "only apply if it actually changed" short-circuit must
    // be bypassed here or the cat would freeze on the last sit frame
    // whenever the real mood happens to already equal idle.
    _applyDesiredMood(force: true);
  }

  /// Natural response to a tap. The very first tap (cat still asleep)
  /// plays the full wake-up sequence exactly as before. Every tap after
  /// that instead plays a quick, already-loaded "look" reaction and
  /// returns to the cat's current mood — a snappy acknowledgement instead
  /// of forcing the entire ~16s Sleep/Wake/Stretch/Look/Sit chain to
  /// replay every time.
  Future<void> reactToTap() async {
    // Already mid-wake-up — let it finish undisturbed, exactly like a
    // repeated tap during that sequence has always been ignored.
    if (_isWaking) return;

    if (!_hasWokenUp) {
      await wakeUp();
      return;
    }

    // A reaction is already playing — don't stack another on top of it.
    if (_reacting) return;

    _reacting = true;

    if (cat.isMounted) {
      cat.animation = lookAnimation;
    }

    await Future.delayed(const Duration(milliseconds: 3600));

    // Only settle if nothing else (e.g. a fresh wakeUp()) has taken over
    // cat.animation while we were waiting. Settles to the cat's current
    // mood rather than unconditionally idle, so a tap during e.g. a
    // hungry mood doesn't leave the display incorrectly stuck on idle.
    // Forced for the same reason as wakeUp()'s completion: cat.animation
    // is currently showing lookAnimation, not _appliedMood's animation,
    // so the mood must be re-applied even if _desiredMood didn't change
    // while the reaction was playing.
    if (_reacting) {
      _reacting = false;
      _applyDesiredMood(force: true);
    }
  }

  /// Records the cat's current real-world mood, requested by GameScreen on
  /// every rebuild.
  ///
  /// CatAnimation has zero knowledge of VirtualPetProvider/Hive/Provider —
  /// GameScreen computes the mood via the existing PetBrain (from
  /// hunger/happiness/cleanliness, using PetBrain's own already-defined
  /// priority order) and passes in just the resulting PetState. This is
  /// the only seam between Flame and the rest of the app's state
  /// management, by design.
  ///
  /// Safe to call on every Flutter rebuild. Unlike before, this no longer
  /// touches cat.animation directly when asleep/mid-reaction — it only
  /// records the request (_desiredMood) and defers to _applyDesiredMood,
  /// which is the single place allowed to actually change what's shown.
  /// That's what stops a non-idle starting mood from skipping the wake
  /// sequence, and stops a mood requested mid-wake/mid-reaction from being
  /// silently dropped — see wakeUp()/reactToTap() for where it's re-run
  /// once those finish.
  void setMood(PetState mood) {
    if (!_loaded) return;

    _desiredMood = mood;
    _applyDesiredMood();
  }

  /// Shows _desiredMood if — and only if — nothing else currently owns
  /// cat.animation: the cat must have actually finished waking at least
  /// once, and no wake-up/tap reaction can be mid-flight.
  ///
  /// [force] bypasses the "only if it actually changed" short-circuit.
  /// Needed when the caller (wakeUp()/reactToTap()) knows cat.animation is
  /// currently showing something that ISN'T a mood animation at all (sit/
  /// look), so _appliedMood's last-known value can't be trusted to mean
  /// "this is what's on screen" — without it the cat could freeze on the
  /// last frame of a non-looping sequence whenever the real mood happens
  /// to already equal _appliedMood. setMood() itself always calls this
  /// unforced, since by every point it can run, _appliedMood IS accurate.
  void _applyDesiredMood({bool force = false}) {
    if (!_hasWokenUp || _isWaking || _reacting) return;
    if (!force && _desiredMood == _appliedMood) return;

    _appliedMood = _desiredMood;
    _setAnimationForMood(_appliedMood);
  }

  /// The single place that writes cat.animation for a mood value — used
  /// only by _applyDesiredMood, so _appliedMood can never drift from
  /// what's actually displayed.
  void _setAnimationForMood(PetState mood) {
    if (!cat.isMounted) return;

    switch (mood) {
      case PetState.idle:
      case PetState.clean:
        // PetBrain never actually produces `clean` today — mapped to
        // idle so the switch stays exhaustive without a dead sixth mood.
        cat.animation = idleAnimation;
        break;

      case PetState.happy:
        cat.animation = happyAnimation;
        break;

      case PetState.sad:
        cat.animation = sadAnimation;
        break;

      case PetState.angry:
        cat.animation = angryAnimation;
        break;

      case PetState.dirty:
        cat.animation = dirtyAnimation;
        break;

      case PetState.neglected:
        cat.animation = neglectedAnimation;
        break;
    }
  }
}
