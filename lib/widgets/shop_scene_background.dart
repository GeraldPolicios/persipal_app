import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/reward_service.dart';

/// Displays the currently equipped custom scene background, falling back to
/// the original subtle paw wallpaper when no background has been equipped.
class ShopSceneBackground extends StatelessWidget {
  final String slot;
  const ShopSceneBackground({super.key, required this.slot});

  static const Map<String, String> _assets = {
    'background_room_sunroom_morning': 'assets/packs/room/sunroom.png',
    'background_room_sunroom_noon': 'assets/packs/room/sunroomnoon.png',
    'background_room_sunroom_night': 'assets/packs/room/sunroomnight.png',
    'background_room_laplace_morning': 'assets/packs/room/laplace.png',
    'background_room_laplace_noon': 'assets/packs/room/laplacenoon.png',
    'background_room_laplace_night': 'assets/packs/room/laplacenight.png',
    'background_room_aticroom_morning': 'assets/packs/room/aticroom.png',
    'background_room_aticroom_noon': 'assets/packs/room/aticroomnoon.png',
    'background_room_aticroom_night': 'assets/packs/room/aticroomnight.png',
    'background_feed_persi_morning': 'assets/packs/feed/persi.png',
    'background_feed_persi_noon': 'assets/packs/feed/persinoon.png',
    'background_feed_persi_night': 'assets/packs/feed/persinight.png',
    'background_feed_clearfeed_morning': 'assets/packs/feed/clearfeed.png',
    'background_feed_clearfeed_noon': 'assets/packs/feed/clearfeednoon.png',
    'background_feed_clearfeed_night': 'assets/packs/feed/clearfeednight.png',
    'background_feed_aesthicfeed_morning': 'assets/packs/feed/aesthicfeed.png',
    'background_feed_aesthicfeed_noon': 'assets/packs/feed/aesthicfeednoon.png',
    'background_feed_aesthicfeed_night':
        'assets/packs/feed/aesthicfeednight.png',
    'background_groom_richgroom_morning': 'assets/packs/groom/richgroom.png',
    'background_groom_richgroom_noon': 'assets/packs/groom/richgroomnoon.png',
    'background_groom_richgroom_night': 'assets/packs/groom/richgroomnight.png',
    'background_groom_freshgroom_morning': 'assets/packs/groom/freshgroom.png',
    'background_groom_freshgroom_noon': 'assets/packs/groom/freshgroomnoon.png',
    'background_groom_freshgroom_night':
        'assets/packs/groom/freshgroomnight.png',
    'background_groom_cozygroom_morning': 'assets/packs/groom/cozygroom.png',
    'background_groom_cozygroom_noon': 'assets/packs/groom/cozygroomnoon.png',
    'background_groom_cozygroom_night': 'assets/packs/groom/cozygroomnight.png',
    'background_play_verdiplay_morning': 'assets/packs/play/verdiplay.png',
    'background_play_verdiplay_noon': 'assets/packs/play/verdiplaynoon.png',
    'background_play_verdiplay_night': 'assets/packs/play/verdiplaynight.png',
    'background_play_gardenplay_morning': 'assets/packs/play/gardenplay.png',
    'background_play_gardenplay_noon': 'assets/packs/play/gardenplaynoon.png',
    'background_play_gardenplay_night': 'assets/packs/play/gardenplaynigth.png',
    'background_play_createplay_morning': 'assets/packs/play/createplay.png',
    'background_play_createplay_noon': 'assets/packs/play/createplaynoon.png',
    'background_play_createplay_night': 'assets/packs/play/createplaynight.png',
  };

  @override
  Widget build(BuildContext context) {
    return Consumer<RewardService>(builder: (context, rewards, _) {
      final id = rewards.equippedShopItem(slot);
      final asset = id == null ? null : _assets[id];
      if (asset != null) {
        return Positioned.fill(child: Image.asset(asset, fit: BoxFit.cover));
      }
      return Positioned.fill(
        child: Opacity(
          opacity: 0.12,
          child: Image.asset('assets/images/paws_bg.png', fit: BoxFit.cover),
        ),
      );
    });
  }
}
