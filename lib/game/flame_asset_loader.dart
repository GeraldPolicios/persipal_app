// lib/game/flame_asset_loader.dart
//
// Reusable, downsampling-aware asset loader for the Flame interaction
// engine. Mirrors the exact technique FeedPet/PlayPet already use —
// Image.memory(bytes, cacheHeight: ...) — but produces Flame
// Sprite/SpriteAnimation objects instead of Flutter Image widgets. This
// matters because Flame's own Images.load() does NOT downsample and would
// decode every frame at full source resolution (832x1120+ for these
// assets), which is exactly the regression the performance requirement
// says to avoid. Every frame is decoded, downsampled, and wrapped —
// nothing full-resolution is retained past the decode call.
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flutter/services.dart' show rootBundle;

class FlameAssetLoader {
  const FlameAssetLoader._();

  static Future<ui.Image> _loadDownsampled(
    String assetPath, {
    required int targetHeight,
  }) async {
    final data = await rootBundle.load(assetPath);
    final codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(),
      targetHeight: targetHeight,
    );
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  /// A single static pose, wrapped as a Sprite.
  static Future<Sprite> loadSprite(
    String assetPath, {
    required int targetHeight,
  }) async {
    final image =
        await _loadDownsampled(assetPath, targetHeight: targetHeight);
    return Sprite(image);
  }

  /// A single static pose, wrapped as a 1-frame SpriteAnimation so it can
  /// be assigned to SpriteAnimationComponent.animation exactly like any
  /// multi-frame animation — the same trick CatAnimation already uses for
  /// its own static mood frames (angry/dirty/neglected).
  static Future<SpriteAnimation> loadStaticAnimation(
    String assetPath, {
    required int targetHeight,
  }) async {
    final sprite = await loadSprite(assetPath, targetHeight: targetHeight);
    return SpriteAnimation.spriteList([sprite], stepTime: 1);
  }

  /// A folder of individually-numbered frames (e.g.
  /// happy_cat/happy_0001.png ...), each downsampled the same way. Loads
  /// sequentially rather than in parallel, deliberately, so a large
  /// sequence never has hundreds of decodes in flight at once — see the
  /// "avoid loading hundreds of frames simultaneously" requirement.
  static Future<SpriteAnimation> loadFrameSequence({
    required String folder,
    required String prefix,
    required int count,
    required int targetHeight,
    double stepTime = 0.05,
    int startIndex = 1,
    bool loop = true,
  }) async {
    final sprites = <Sprite>[];

    for (var i = startIndex; i < startIndex + count; i++) {
      sprites.add(await loadSprite(
        'assets/images/$folder/$prefix${i.toString().padLeft(4, '0')}.png',
        targetHeight: targetHeight,
      ));
    }

    return SpriteAnimation.spriteList(
      sprites,
      stepTime: stepTime,
      loop: loop,
    );
  }
}
