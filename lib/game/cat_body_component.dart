// lib/game/cat_body_component.dart
//
// The single reusable "cat" visual — owns its own sprite/animation plus a
// small set of Flame Effect-based movement primitives (moveTo/returnHome/
// flinch). No Provider/Hive/Firestore/ActivityLog knowledge whatsoever —
// purely a PositionComponent with an animation and a position, exactly the
// separation the architecture requires.
import 'dart:async';

import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/animation.dart' show Curves;

class CatBodyComponent extends SpriteAnimationComponent {
  CatBodyComponent({required SpriteAnimation initialAnimation})
      : super(animation: initialAnimation, anchor: Anchor.bottomCenter);

  /// The resting position the cat returns to after a reaction/move. Set by
  /// the owning game once its canvas size is known (onGameResize).
  Vector2 homePosition = Vector2.zero();

  /// Moves to [target] over [duration] seconds. Resolves once the effect
  /// completes OR after a bounded safety timeout, so a caller can never
  /// hang forever even if the component is removed mid-effect and
  /// onComplete never fires (see the action-completion-safety
  /// requirement).
  Future<void> moveTo(
    Vector2 target, {
    double duration = 0.45,
  }) {
    final completer = Completer<void>();

    add(MoveToEffect(
      target,
      EffectController(duration: duration, curve: Curves.easeInOut),
      onComplete: () {
        if (!completer.isCompleted) completer.complete();
      },
    ));

    return completer.future.timeout(
      Duration(milliseconds: (duration * 1000).round() + 800),
      onTimeout: () {},
    );
  }

  /// Eases back to [homePosition].
  Future<void> returnHome({double duration = 0.45}) =>
      moveTo(homePosition, duration: duration);

  /// A small there-and-back positional "body reaction" — real Flame
  /// movement (not a PNG swap) used for Groom's Soap/Shower/Brush reaction
  /// and Trim's per-stage flinch.
  Future<void> flinch({
    double dx = 6,
    double duration = 0.08,
  }) {
    final completer = Completer<void>();

    add(MoveByEffect(
      Vector2(dx, 0),
      EffectController(
        duration: duration,
        reverseDuration: duration,
        curve: Curves.easeInOut,
      ),
      onComplete: () {
        if (!completer.isCompleted) completer.complete();
      },
    ));

    return completer.future.timeout(
      Duration(milliseconds: (duration * 2 * 1000).round() + 800),
      onTimeout: () {},
    );
  }
}
