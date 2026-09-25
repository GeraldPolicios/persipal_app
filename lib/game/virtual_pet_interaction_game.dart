// lib/game/virtual_pet_interaction_game.dart
//
// ONE reusable Flame interaction engine, meant to be embedded by
// FeedScreen/GroomScreen/PlayScreen alike (Phase 1: GroomScreen only).
// Owns cat visual state, movement, and reaction sequencing — nothing else.
// It has zero knowledge of VirtualPetProvider/Hive/Firestore/
// ActivityLogService/achievements; the hosting screen calls its narrow
// imperative commands and (optionally) awaits their Future, then performs
// the existing persistence/logging exactly as before.
//
// Phase 1 wires up only what GroomScreen needs: groom()/setFurStage()/
// finishTrim()/returnToIdle(). eat()/playWith() are intentionally NOT
// implemented yet — later phases add them to this same class, reusing the
// same CatBodyComponent/FlameAssetLoader, rather than creating a second
// engine.
import 'dart:async';

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart' show Color, debugPrint;

import 'cat_body_component.dart';
import 'flame_asset_loader.dart';
import 'interaction_state.dart';

class VirtualPetInteractionGame extends FlameGame {
  VirtualPetInteractionGame({this.displayHeight = 95});

  /// The intended on-screen render height (logical pixels) — matches
  /// whatever the hosting screen sizes its GameWidget box to. Drives the
  /// asset loader's downsample target, the same height-based cacheHeight
  /// convention FeedPet/PlayPet already use (height * 3).
  final double displayHeight;

  /// Null until onLoad() finishes successfully. Every public command below
  /// guards on this being non-null, so a load failure degrades to "no
  /// visible cat" instead of a crash or a command that hangs forever.
  CatBodyComponent? cat;

  final Completer<void> _readyCompleter = Completer<void>();

  /// Completes once onLoad() has finished (successfully or not) — mirrors
  /// CatAnimation's own catReady. Named catReady (not `ready`) because
  /// FlameGame already defines its own `ready`.
  Future<void> get catReady => _readyCompleter.future;

  CatActivity _activity = CatActivity.idle;
  int _furStage = 3;

  SpriteAnimation? _furStage1Anim;
  SpriteAnimation? _furStage2Anim;
  SpriteAnimation? _furStage3Anim;
  SpriteAnimation? _idlePoseAnim;
  SpriteAnimation? _dirtyPoseAnim;
  SpriteAnimation? _happyAnim;

  @override
  Color backgroundColor() => const Color(0x00000000);

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    try {
      final targetHeight = (displayHeight * 3).round();

      _furStage3Anim = await FlameAssetLoader.loadStaticAnimation(
        'assets/images/states/fur_cat3.png',
        targetHeight: targetHeight,
      );
      _furStage2Anim = await FlameAssetLoader.loadStaticAnimation(
        'assets/images/states/fur_cat2.png',
        targetHeight: targetHeight,
      );
      _furStage1Anim = await FlameAssetLoader.loadStaticAnimation(
        'assets/images/states/fur_cat1.png',
        targetHeight: targetHeight,
      );
      _idlePoseAnim = await FlameAssetLoader.loadStaticAnimation(
        'assets/images/idle/frame_0001.png',
        targetHeight: targetHeight,
      );
      _dirtyPoseAnim = await FlameAssetLoader.loadStaticAnimation(
        'assets/images/states/dirty_cat.png',
        targetHeight: targetHeight,
      );
      // 31 frames — small enough to preload eagerly (the same asset is
      // already preloaded the same way by CatAnimation's own mood system).
      _happyAnim = await FlameAssetLoader.loadFrameSequence(
        folder: 'happy_cat',
        prefix: 'happy_',
        count: 31,
        targetHeight: targetHeight,
        stepTime: 0.05,
      );

      final catComponent = CatBodyComponent(initialAnimation: _furStage3Anim!);
      cat = catComponent;
      await add(catComponent);
      _positionCatAtHome();
    } catch (e) {
      debugPrint('VirtualPetInteractionGame: asset load failed: $e');
      // `cat` stays null — every command below already guards on it.
    } finally {
      if (!_readyCompleter.isCompleted) _readyCompleter.complete();
    }
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _positionCatAtHome();
  }

  void _positionCatAtHome() {
    final c = cat;
    if (c == null) return;
    c.position = Vector2(size.x / 2, size.y);
    c.homePosition = c.position.clone();
  }

  void _restCurrentFurPose() {
    final c = cat;
    if (c == null) return;

    switch (_furStage) {
      case 1:
        c.animation = _furStage1Anim ?? c.animation;
        break;
      case 2:
        c.animation = _furStage2Anim ?? c.animation;
        break;
      default:
        c.animation = _furStage3Anim ?? c.animation;
    }
  }

  // ── Public commands ───────────────────────────────────────────────────
  // Every command below is wrapped so it can never hang or throw past its
  // own Future — an asset failure, a disposed component, or an unexpected
  // exception all degrade to "no visual reaction" rather than blocking the
  // caller, per the action-completion-safety requirement.

  /// Soap/Shower/Brush reaction: a brief happy animation plus a small
  /// positional flinch (real Flame movement, not a PNG swap), then back to
  /// the current fur-stage pose. Trim does NOT call this — see
  /// setFurStage()/finishTrim() below.
  Future<void> groom(GroomTool tool) async {
    if (cat == null) return;
    // Guards against overlapping reactions if tools are dropped in rapid
    // succession — stats/Activity Log still update every time on the
    // Flutter side regardless; only the Flame visual is throttled.
    if (_activity != CatActivity.idle) return;

    _activity = CatActivity.reacting;

    try {
      await catReady;
      final c = cat;
      if (c == null) return;

      if (_happyAnim != null) {
        c.animation = _happyAnim;
      }

      await c.flinch();
      await Future.delayed(const Duration(milliseconds: 500));
    } catch (e) {
      debugPrint('VirtualPetInteractionGame.groom failed: $e');
    } finally {
      _restCurrentFurPose();
      _activity = CatActivity.idle;
    }
  }

  /// Called as Trim's existing pan gesture crosses each fur-stage
  /// threshold. Adds a subtle flinch and swaps to the corresponding
  /// fur_cat pose — the gesture itself stays entirely in Flutter.
  Future<void> setFurStage(int stage) async {
    _furStage = stage.clamp(1, 3);

    final c = cat;
    if (c == null) return;

    try {
      await c.flinch(dx: 4, duration: 0.06);
    } catch (e) {
      debugPrint('VirtualPetInteractionGame.setFurStage failed: $e');
    }

    _restCurrentFurPose();
  }

  /// Called once, the moment Trim's gesture completes — swaps to the final
  /// idle/dirty pose, matching GroomScreen's existing post-trim display.
  Future<void> finishTrim({required bool dirty}) async {
    final c = cat;
    if (c == null) return;

    try {
      c.animation = dirty ? (_dirtyPoseAnim ?? c.animation) : (_idlePoseAnim ?? c.animation);
    } catch (e) {
      debugPrint('VirtualPetInteractionGame.finishTrim failed: $e');
    }
  }

  /// Generic reset — eases back to the home position and the current fur
  /// pose. Not required by Phase 1's Groom flow (groom() already settles
  /// itself), but part of the required command surface for later phases.
  Future<void> returnToIdle() async {
    final c = cat;
    if (c == null) return;

    try {
      await c.returnHome();
    } catch (e) {
      debugPrint('VirtualPetInteractionGame.returnToIdle failed: $e');
    }

    _restCurrentFurPose();
    _activity = CatActivity.idle;
  }
}
