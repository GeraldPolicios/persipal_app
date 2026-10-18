// lib/screens/shop_screen.dart
//
// Persipal's in-app shop. The balance comes from the existing RewardService,
// so the Shop does not create a second points/currency system.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/reward_service.dart';
import '../services/virtual_cat_progress_service.dart';
import '../themes/app_theme.dart';
import '../widgets/shared_widgets.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  static const _categories = <String>[
    'Grooming',
    'Feed',
    'Play',
    'Decor',
    'All Rooms',
    'Care',
  ];

  final _catProgress = VirtualCatProgressService.instance;

  String _selectedRoom = 'Room';
  String _selectedTime = 'Morning';

  static const _roomTypes = <String>['Room', 'Feed', 'Groom', 'Play'];
  static const _times = <String>['Morning', 'Noon', 'Night'];

  // Keep the existing in-game emoji/items. Variants are distinguished by the
  // card color so no new sprite sheets or artwork are needed.
  static const _items = <ShopItem>[
    ShopItem(
        id: 'grooming_soap_mint',
        category: 'Grooming',
        emoji: '🧼',
        name: 'Mint Soap Card',
        description: 'Changes the background color of the soap card to mint.',
        price: 90,
        color: Color(0xFFDDF4E7)),
    ShopItem(
        id: 'grooming_shower_pink',
        category: 'Grooming',
        emoji: '🚿',
        name: 'Pink Shower Card',
        description: 'Changes the background color of the shower card to pink.',
        price: 110,
        color: Color(0xFFFFDCE8)),
    ShopItem(
        id: 'grooming_blower_blue',
        category: 'Grooming',
        emoji: '💨',
        name: 'Blue Blower Card',
        description: 'Changes the background color of the blower card to blue.',
        price: 140,
        color: Color(0xFFD9EEFF),
        imageAsset: 'assets/images/items/blower.png'),
    ShopItem(
        id: 'grooming_towel_lilac',
        category: 'Grooming',
        emoji: '🧻',
        name: 'Lilac Towel Card',
        description: 'Changes the background color of the towel card to lilac.',
        price: 110,
        color: Color(0xFFEADFFF),
        imageAsset: 'assets/images/items/towel.png'),
    ShopItem(
        id: 'grooming_trim_peach',
        category: 'Grooming',
        emoji: '✂️',
        name: 'Peach Trim Card',
        description: 'Changes the background color of the trim card to peach.',
        price: 130,
        color: Color(0xFFFFE2D4)),
    ShopItem(
        id: 'grooming_brush_mint',
        category: 'Grooming',
        emoji: '🪮',
        name: 'Mint Brush Card',
        description: 'Changes the background color of the brush card to mint.',
        price: 100,
        color: Color(0xFFDDF4E7)),
    ShopItem(
        id: 'grooming_soap_pink',
        category: 'Grooming',
        emoji: '🧼',
        name: 'Pink Soap Card',
        description: 'Changes the background color of the soap card to pink.',
        price: 90,
        color: Color(0xFFFFDCE8)),
    ShopItem(
        id: 'grooming_shower_blue',
        category: 'Grooming',
        emoji: '🚿',
        name: 'Blue Shower Card',
        description: 'Changes the background color of the shower card to blue.',
        price: 110,
        color: Color(0xFFD9EEFF)),
    ShopItem(
        id: 'grooming_blower_lilac',
        category: 'Grooming',
        emoji: '💨',
        name: 'Lilac Blower Card',
        description:
            'Changes the background color of the blower card to lilac.',
        price: 140,
        color: Color(0xFFEADFFF),
        imageAsset: 'assets/images/items/blower.png'),
    ShopItem(
        id: 'grooming_towel_peach',
        category: 'Grooming',
        emoji: '🧻',
        name: 'Peach Towel Card',
        description: 'Changes the background color of the towel card to peach.',
        price: 110,
        color: Color(0xFFFFE2D4),
        imageAsset: 'assets/images/items/towel.png'),
    ShopItem(
        id: 'grooming_trim_mint',
        category: 'Grooming',
        emoji: '✂️',
        name: 'Mint Trim Card',
        description: 'Changes the background color of the trim card to mint.',
        price: 130,
        color: Color(0xFFDDF4E7)),
    ShopItem(
        id: 'grooming_brush_pink',
        category: 'Grooming',
        emoji: '🪮',
        name: 'Pink Brush Card',
        description: 'Changes the background color of the brush card to pink.',
        price: 100,
        color: Color(0xFFFFDCE8)),
    ShopItem(
        id: 'grooming_soap_blue',
        category: 'Grooming',
        emoji: '🧼',
        name: 'Blue Soap Card',
        description: 'Changes the background color of the soap card to blue.',
        price: 90,
        color: Color(0xFFD9EEFF)),
    ShopItem(
        id: 'grooming_shower_lilac',
        category: 'Grooming',
        emoji: '🚿',
        name: 'Lilac Shower Card',
        description:
            'Changes the background color of the shower card to lilac.',
        price: 110,
        color: Color(0xFFEADFFF)),
    ShopItem(
        id: 'grooming_blower_peach',
        category: 'Grooming',
        emoji: '💨',
        name: 'Peach Blower Card',
        description:
            'Changes the background color of the blower card to peach.',
        price: 140,
        color: Color(0xFFFFE2D4),
        imageAsset: 'assets/images/items/blower.png'),
    ShopItem(
        id: 'feed_dryfood_mint',
        category: 'Feed',
        emoji: '🥣',
        name: 'Mint Dry Food Card',
        description:
            'Changes the background color of the dry food card to mint.',
        price: 60,
        color: Color(0xFFDDF4E7)),
    ShopItem(
        id: 'feed_wetfood_pink',
        category: 'Feed',
        emoji: '🥫',
        name: 'Pink Wet Food Card',
        description:
            'Changes the background color of the wet food card to pink.',
        price: 60,
        color: Color(0xFFFFDCE8)),
    ShopItem(
        id: 'feed_fish_blue',
        category: 'Feed',
        emoji: '🐟',
        name: 'Blue Fish Card',
        description: 'Changes the background color of the fish card to blue.',
        price: 60,
        color: Color(0xFFD9EEFF)),
    ShopItem(
        id: 'feed_milk_lilac',
        category: 'Feed',
        emoji: '🥛',
        name: 'Lilac Milk Card',
        description: 'Changes the background color of the milk card to lilac.',
        price: 60,
        color: Color(0xFFEADFFF)),
    ShopItem(
        id: 'feed_water_peach',
        category: 'Feed',
        emoji: '💧',
        name: 'Peach Water Card',
        description: 'Changes the background color of the water card to peach.',
        price: 50,
        color: Color(0xFFFFE2D4)),
    ShopItem(
        id: 'feed_treat_mint',
        category: 'Feed',
        emoji: '🥩',
        name: 'Mint Treat Card',
        description: 'Changes the background color of the treat card to mint.',
        price: 80,
        color: Color(0xFFDDF4E7)),
    ShopItem(
        id: 'feed_unsafe_pink',
        category: 'Feed',
        emoji: '🍫',
        name: 'Pink Unsafe Food Card',
        description:
            'Changes the background color of the chocolate, onion, and garlic cards to pink.',
        price: 80,
        color: Color(0xFFFFDCE8)),
    ShopItem(
        id: 'feed_dryfood_pink',
        category: 'Feed',
        emoji: '🥣',
        name: 'Pink Dry Food Card',
        description:
            'Changes the background color of the dry food card to pink.',
        price: 60,
        color: Color(0xFFFFDCE8)),
    ShopItem(
        id: 'feed_wetfood_blue',
        category: 'Feed',
        emoji: '🥫',
        name: 'Blue Wet Food Card',
        description:
            'Changes the background color of the wet food card to blue.',
        price: 60,
        color: Color(0xFFD9EEFF)),
    ShopItem(
        id: 'feed_fish_lilac',
        category: 'Feed',
        emoji: '🐟',
        name: 'Lilac Fish Card',
        description: 'Changes the background color of the fish card to lilac.',
        price: 60,
        color: Color(0xFFEADFFF)),
    ShopItem(
        id: 'feed_milk_peach',
        category: 'Feed',
        emoji: '🥛',
        name: 'Peach Milk Card',
        description: 'Changes the background color of the milk card to peach.',
        price: 60,
        color: Color(0xFFFFE2D4)),
    ShopItem(
        id: 'feed_water_mint',
        category: 'Feed',
        emoji: '💧',
        name: 'Mint Water Card',
        description: 'Changes the background color of the water card to mint.',
        price: 50,
        color: Color(0xFFDDF4E7)),
    ShopItem(
        id: 'feed_treat_pink',
        category: 'Feed',
        emoji: '🥩',
        name: 'Pink Treat Card',
        description: 'Changes the background color of the treat card to pink.',
        price: 80,
        color: Color(0xFFFFDCE8)),
    ShopItem(
        id: 'feed_dryfood_blue',
        category: 'Feed',
        emoji: '🥣',
        name: 'Blue Dry Food Card',
        description:
            'Changes the background color of the dry food card to blue.',
        price: 60,
        color: Color(0xFFD9EEFF)),
    ShopItem(
        id: 'feed_wetfood_lilac',
        category: 'Feed',
        emoji: '🥫',
        name: 'Lilac Wet Food Card',
        description:
            'Changes the background color of the wet food card to lilac.',
        price: 60,
        color: Color(0xFFEADFFF)),
    ShopItem(
        id: 'feed_fish_peach',
        category: 'Feed',
        emoji: '🐟',
        name: 'Peach Fish Card',
        description: 'Changes the background color of the fish card to peach.',
        price: 60,
        color: Color(0xFFFFE2D4)),
    ShopItem(
        id: 'play_tennisball_mint',
        category: 'Play',
        emoji: '🎾',
        name: 'Mint Tennis Ball Card',
        description:
            'Changes the background color of the tennis ball card to mint.',
        price: 80,
        color: Color(0xFFBFE8D2)),
    ShopItem(
        id: 'play_feather_pink',
        category: 'Play',
        emoji: '🪶',
        name: 'Pink Feather Card',
        description:
            'Changes the background color of the feather card to pink.',
        price: 80,
        color: Color(0xFFFFC5D8)),
    ShopItem(
        id: 'play_laserdot_blue',
        category: 'Play',
        emoji: '🔴',
        name: 'Blue Laser Dot Card',
        description:
            'Changes the background color of the laser dot card to blue.',
        price: 90,
        color: Color(0xFFB7D9F8)),
    ShopItem(
        id: 'play_yarnball_lilac',
        category: 'Play',
        emoji: '🧶',
        name: 'Lilac Yarn Ball Card',
        description:
            'Changes the background color of the yarn ball card to lilac.',
        price: 90,
        color: Color(0xFFD8C7F2)),
    ShopItem(
        id: 'play_tennisball_peach',
        category: 'Play',
        emoji: '🎾',
        name: 'Peach Tennis Ball Card',
        description:
            'Changes the background color of the tennis ball card to peach.',
        price: 80,
        color: Color(0xFFFFD0B5)),
    ShopItem(
        id: 'play_feather_mint',
        category: 'Play',
        emoji: '🪶',
        name: 'Mint Feather Card',
        description:
            'Changes the background color of the feather card to mint.',
        price: 80,
        color: Color(0xFFA9DED0)),
    ShopItem(
        id: 'play_laserdot_pink',
        category: 'Play',
        emoji: '🔴',
        name: 'Pink Laser Dot Card',
        description:
            'Changes the background color of the laser dot card to pink.',
        price: 90,
        color: Color(0xFFFFAEC7)),
    ShopItem(
        id: 'play_yarnball_blue',
        category: 'Play',
        emoji: '🧶',
        name: 'Blue Yarn Ball Card',
        description:
            'Changes the background color of the yarn ball card to blue.',
        price: 90,
        color: Color(0xFFD9EEFF)),
    ShopItem(
        id: 'play_tennisball_lilac',
        category: 'Play',
        emoji: '🎾',
        name: 'Lilac Tennis Ball Card',
        description:
            'Changes the background color of the tennis ball card to lilac.',
        price: 80,
        color: Color(0xFFEADFFF)),
    ShopItem(
        id: 'play_feather_peach',
        category: 'Play',
        emoji: '🪶',
        name: 'Peach Feather Card',
        description:
            'Changes the background color of the feather card to peach.',
        price: 80,
        color: Color(0xFFFFE2D4)),
    ShopItem(
        id: 'play_laserdot_mint',
        category: 'Play',
        emoji: '🔴',
        name: 'Mint Laser Dot Card',
        description:
            'Changes the background color of the laser dot card to mint.',
        price: 90,
        color: Color(0xFFDDF4E7)),
    ShopItem(
        id: 'play_yarnball_pink',
        category: 'Play',
        emoji: '🧶',
        name: 'Pink Yarn Ball Card',
        description:
            'Changes the background color of the yarn ball card to pink.',
        price: 90,
        color: Color(0xFFFFDCE8)),
    ShopItem(
        id: 'play_tennisball_blue',
        category: 'Play',
        emoji: '🎾',
        name: 'Blue Tennis Ball Card',
        description:
            'Changes the background color of the tennis ball card to blue.',
        price: 80,
        color: Color(0xFFD9EEFF)),
    ShopItem(
        id: 'play_feather_lilac',
        category: 'Play',
        emoji: '🪶',
        name: 'Lilac Feather Card',
        description:
            'Changes the background color of the feather card to lilac.',
        price: 80,
        color: Color(0xFFEADFFF)),
    ShopItem(
        id: 'play_laserdot_peach',
        category: 'Play',
        emoji: '🔴',
        name: 'Peach Laser Dot Card',
        description:
            'Changes the background color of the laser dot card to peach.',
        price: 90,
        color: Color(0xFFFFE2D4)),
    ShopItem(
        id: 'decor_teddybear',
        category: 'Room Decor',
        emoji: '🧸',
        name: 'Tiny Teddy Bear',
        description: 'A small decoration for the side of the game room.',
        price: 200,
        color: Color(0xFFDDF4E7)),
    ShopItem(
        id: 'decor_pottedplant',
        category: 'Room Decor',
        emoji: '🪴',
        name: 'Tiny Potted Plant',
        description: 'A small decoration for the side of the game room.',
        price: 150,
        color: Color(0xFFFFDCE8)),
    ShopItem(
        id: 'decor_littlestar',
        category: 'Room Decor',
        emoji: '⭐',
        name: 'Tiny Little Star',
        description: 'A small decoration for the side of the game room.',
        price: 130,
        color: Color(0xFFD9EEFF)),
    ShopItem(
        id: 'decor_tinymushroom',
        category: 'Room Decor',
        emoji: '🍄',
        name: 'Tiny Tiny Mushroom',
        description: 'A small decoration for the side of the game room.',
        price: 140,
        color: Color(0xFFEADFFF)),
    ShopItem(
        id: 'decor_smallflower',
        category: 'Room Decor',
        emoji: '🌼',
        name: 'Tiny Small Flower',
        description: 'A small decoration for the side of the game room.',
        price: 110,
        color: Color(0xFFFFE2D4)),
    ShopItem(
        id: 'decor_minilamp',
        category: 'Room Decor',
        emoji: '🏮',
        name: 'Tiny Mini Lamp',
        description: 'A small decoration for the side of the game room.',
        price: 160,
        color: Color(0xFFDDF4E7)),
    ShopItem(
        id: 'decor_tinycloud',
        category: 'Room Decor',
        emoji: '☁️',
        name: 'Tiny Tiny Cloud',
        description: 'A small decoration for the side of the game room.',
        price: 100,
        color: Color(0xFFFFDCE8)),
    ShopItem(
        id: 'decor_littlecactus',
        category: 'Room Decor',
        emoji: '🌵',
        name: 'Tiny Little Cactus',
        description: 'A small decoration for the side of the game room.',
        price: 130,
        color: Color(0xFFD9EEFF)),
    ShopItem(
        id: 'decor_smallbell',
        category: 'Room Decor',
        emoji: '🔔',
        name: 'Tiny Small Bell',
        description: 'A small decoration for the side of the game room.',
        price: 110,
        color: Color(0xFFEADFFF)),
    ShopItem(
        id: 'decor_miniclock',
        category: 'Room Decor',
        emoji: '🕒',
        name: 'Tiny Mini Clock',
        description: 'A small decoration for the side of the game room.',
        price: 150,
        color: Color(0xFFFFE2D4)),
    ShopItem(
        id: 'feed_chocolate_u1',
        category: 'Feed',
        emoji: '🍫',
        name: 'Pink Chocolate Card',
        description: 'Changes only the chocolate card in Feed to pink.',
        price: 90,
        color: Color(0xFFFFC6D9)),
    ShopItem(
        id: 'feed_garlic_u2',
        category: 'Feed',
        emoji: '🧄',
        name: 'Blue Garlic Card',
        description: 'Changes only the garlic card in Feed to blue.',
        price: 90,
        color: Color(0xFFB9DFFF)),
    ShopItem(
        id: 'feed_onion_u3',
        category: 'Feed',
        emoji: '🧅',
        name: 'Gray Onion Card',
        description: 'Changes only the onion card in Feed to gray.',
        price: 90,
        color: Color(0xFFD6D6DE)),
    ShopItem(
        id: 'feed_dryfood_u4',
        category: 'Feed',
        emoji: '🥣',
        name: 'Coral Dry Food Card',
        description: 'Changes only the dry food card in Feed to coral.',
        price: 90,
        color: Color(0xFFFFB4A2)),
    ShopItem(
        id: 'feed_wetfood_u5',
        category: 'Feed',
        emoji: '🥫',
        name: 'Yellow Wet Food Card',
        description: 'Changes only the wet food card in Feed to yellow.',
        price: 90,
        color: Color(0xFFFFE29A)),
    ShopItem(
        id: 'feed_fish_u6',
        category: 'Feed',
        emoji: '🐟',
        name: 'Teal Fish Card',
        description: 'Changes only the fish card in Feed to teal.',
        price: 90,
        color: Color(0xFF8FE3D1)),
    ShopItem(
        id: 'feed_milk_u7',
        category: 'Feed',
        emoji: '🥛',
        name: 'Lavender Milk Card',
        description: 'Changes only the milk card in Feed to lavender.',
        price: 90,
        color: Color(0xFFCDBDFF)),
    ShopItem(
        id: 'feed_water_u8',
        category: 'Feed',
        emoji: '💧',
        name: 'Sky Water Card',
        description: 'Changes only the water card in Feed to sky.',
        price: 90,
        color: Color(0xFFA9D9FF)),
    ShopItem(
        id: 'feed_treat_u9',
        category: 'Feed',
        emoji: '🥩',
        name: 'Rose Treat Card',
        description: 'Changes only the treat card in Feed to rose.',
        price: 90,
        color: Color(0xFFFFA6B7)),
    ShopItem(
        id: 'feed_chocolate_u10',
        category: 'Feed',
        emoji: '🍫',
        name: 'Mint Chocolate Card',
        description: 'Changes only the chocolate card in Feed to mint.',
        price: 90,
        color: Color(0xFFB7F0C4)),
    ShopItem(
        id: 'feed_garlic_u11',
        category: 'Feed',
        emoji: '🧄',
        name: 'Peach Garlic Card',
        description: 'Changes only the garlic card in Feed to peach.',
        price: 90,
        color: Color(0xFFFFCFB4)),
    ShopItem(
        id: 'feed_onion_u12',
        category: 'Feed',
        emoji: '🧅',
        name: 'Lilac Onion Card',
        description: 'Changes only the onion card in Feed to lilac.',
        price: 90,
        color: Color(0xFFE6B8FF)),
    ShopItem(
        id: 'feed_dryfood_u13',
        category: 'Feed',
        emoji: '🥣',
        name: 'Lemon Dry Food Card',
        description: 'Changes only the dry food card in Feed to lemon.',
        price: 90,
        color: Color(0xFFF4F59C)),
    ShopItem(
        id: 'feed_wetfood_u14',
        category: 'Feed',
        emoji: '🥫',
        name: 'Aqua Wet Food Card',
        description: 'Changes only the wet food card in Feed to aqua.',
        price: 90,
        color: Color(0xFF9DEBE8)),
    ShopItem(
        id: 'feed_fish_u15',
        category: 'Feed',
        emoji: '🐟',
        name: 'Mauve Fish Card',
        description: 'Changes only the fish card in Feed to mauve.',
        price: 90,
        color: Color(0xFFE9B4D8)),
    ShopItem(
        id: 'feed_milk_u16',
        category: 'Feed',
        emoji: '🥛',
        name: 'Periwinkle Milk Card',
        description: 'Changes only the milk card in Feed to periwinkle.',
        price: 90,
        color: Color(0xFFB9C5FF)),
    ShopItem(
        id: 'feed_water_u17',
        category: 'Feed',
        emoji: '💧',
        name: 'Apricot Water Card',
        description: 'Changes only the water card in Feed to apricot.',
        price: 90,
        color: Color(0xFFFFD0A1)),
    ShopItem(
        id: 'feed_treat_u18',
        category: 'Feed',
        emoji: '🥩',
        name: 'Sage Treat Card',
        description: 'Changes only the treat card in Feed to sage.',
        price: 90,
        color: Color(0xFFC9E0B5)),
    ShopItem(
        id: 'feed_chocolate_u19',
        category: 'Feed',
        emoji: '🍫',
        name: 'Silver Chocolate Card',
        description: 'Changes only the chocolate card in Feed to silver.',
        price: 90,
        color: Color(0xFFE2E4E8)),
    ShopItem(
        id: 'feed_garlic_u20',
        category: 'Feed',
        emoji: '🧄',
        name: 'Plum Garlic Card',
        description: 'Changes only the garlic card in Feed to plum.',
        price: 90,
        color: Color(0xFFD8A7E8)),
    ShopItem(
        id: 'grooming_soap_u1',
        category: 'Grooming',
        emoji: '🧼',
        name: 'Lemon Soap Card',
        description: 'Changes only the soap card in Groom to lemon.',
        price: 90,
        color: Color(0xFFFFF09B)),
    ShopItem(
        id: 'grooming_brush_u2',
        category: 'Grooming',
        emoji: '🪮',
        name: 'Aqua Brush Card',
        description: 'Changes only the brush card in Groom to aqua.',
        price: 90,
        color: Color(0xFF9DEBE8)),
    ShopItem(
        id: 'grooming_towel_u3',
        category: 'Grooming',
        emoji: '🧻',
        name: 'Rose Towel Card',
        description: 'Changes only the towel card in Groom to rose.',
        price: 90,
        color: Color(0xFFFFA6B7),
        imageAsset: 'assets/images/items/towel.png'),
    ShopItem(
        id: 'grooming_scissors_u4',
        category: 'Grooming',
        emoji: '✂️',
        name: 'Sage Scissors Card',
        description: 'Changes only the scissors card in Groom to sage.',
        price: 90,
        color: Color(0xFFC9E0B5)),
    ShopItem(
        id: 'grooming_blower_u5',
        category: 'Grooming',
        emoji: '💨',
        name: 'Periwinkle Blower Card',
        description: 'Changes only the blower card in Groom to periwinkle.',
        price: 90,
        color: Color(0xFFB9C5FF),
        imageAsset: 'assets/images/items/blower.png'),
    ShopItem(
        id: 'background_room_sunroom_morning',
        category: 'Room Decor',
        emoji: '🖼️',
        name: 'Sunroom · Morning',
        description: 'Equip this morning background for room decor.',
        price: 200,
        color: Color(0xFFEADFFF),
        imageAsset: 'assets/packs/room/sunroom.png',
        equipSlot: 'background_room',
        backgroundItem: true),
    ShopItem(
        id: 'background_room_sunroom_noon',
        category: 'Room Decor',
        emoji: '🖼️',
        name: 'Sunroom · Noon',
        description: 'Equip this noon background for room decor.',
        price: 200,
        color: Color(0xFFEADFFF),
        imageAsset: 'assets/packs/room/sunroomnoon.png',
        equipSlot: 'background_room',
        backgroundItem: true),
    ShopItem(
        id: 'background_room_sunroom_night',
        category: 'Room Decor',
        emoji: '🖼️',
        name: 'Sunroom · Night',
        description: 'Equip this night background for room decor.',
        price: 200,
        color: Color(0xFFEADFFF),
        imageAsset: 'assets/packs/room/sunroomnight.png',
        equipSlot: 'background_room',
        backgroundItem: true),
    ShopItem(
        id: 'background_room_laplace_morning',
        category: 'Room Decor',
        emoji: '🖼️',
        name: 'Laplace · Morning',
        description: 'Equip this morning background for room decor.',
        price: 200,
        color: Color(0xFFEADFFF),
        imageAsset: 'assets/packs/room/laplace.png',
        equipSlot: 'background_room',
        backgroundItem: true),
    ShopItem(
        id: 'background_room_laplace_noon',
        category: 'Room Decor',
        emoji: '🖼️',
        name: 'Laplace · Noon',
        description: 'Equip this noon background for room decor.',
        price: 200,
        color: Color(0xFFEADFFF),
        imageAsset: 'assets/packs/room/laplacenoon.png',
        equipSlot: 'background_room',
        backgroundItem: true),
    ShopItem(
        id: 'background_room_laplace_night',
        category: 'Room Decor',
        emoji: '🖼️',
        name: 'Laplace · Night',
        description: 'Equip this night background for room decor.',
        price: 200,
        color: Color(0xFFEADFFF),
        imageAsset: 'assets/packs/room/laplacenight.png',
        equipSlot: 'background_room',
        backgroundItem: true),
    ShopItem(
        id: 'background_room_aticroom_morning',
        category: 'Room Decor',
        emoji: '🖼️',
        name: 'Atic Room · Morning',
        description: 'Equip this morning background for room decor.',
        price: 200,
        color: Color(0xFFEADFFF),
        imageAsset: 'assets/packs/room/aticroom.png',
        equipSlot: 'background_room',
        backgroundItem: true),
    ShopItem(
        id: 'background_room_aticroom_noon',
        category: 'Room Decor',
        emoji: '🖼️',
        name: 'Atic Room · Noon',
        description: 'Equip this noon background for room decor.',
        price: 200,
        color: Color(0xFFEADFFF),
        imageAsset: 'assets/packs/room/aticroomnoon.png',
        equipSlot: 'background_room',
        backgroundItem: true),
    ShopItem(
        id: 'background_room_aticroom_night',
        category: 'Room Decor',
        emoji: '🖼️',
        name: 'Atic Room · Night',
        description: 'Equip this night background for room decor.',
        price: 200,
        color: Color(0xFFEADFFF),
        imageAsset: 'assets/packs/room/aticroomnight.png',
        equipSlot: 'background_room',
        backgroundItem: true),
    ShopItem(
        id: 'feed_dryfood_lilac',
        category: 'Feed',
        emoji: '🥣',
        name: 'Lilac Dry Food Card',
        description:
            'Changes the background color of the dry food card to lilac.',
        price: 60,
        color: Color(0xFFEADFFF)),
    ShopItem(
        id: 'feed_wetfood_peach',
        category: 'Feed',
        emoji: '🥫',
        name: 'Peach Wet Food Card',
        description:
            'Changes the background color of the wet food card to peach.',
        price: 60,
        color: Color(0xFFFFE2D4)),
    ShopItem(
        id: 'feed_fish_mint',
        category: 'Feed',
        emoji: '🐟',
        name: 'Mint Fish Card',
        description: 'Changes the background color of the fish card to mint.',
        price: 60,
        color: Color(0xFFDDF4E7)),
    ShopItem(
        id: 'background_feed_persi_morning',
        category: 'Feed',
        emoji: '🖼️',
        name: 'Persi · Morning',
        description: 'Equip this morning background for feed.',
        price: 200,
        color: Color(0xFFEADFFF),
        imageAsset: 'assets/packs/feed/persi.png',
        equipSlot: 'background_feed',
        backgroundItem: true),
    ShopItem(
        id: 'background_feed_persi_noon',
        category: 'Feed',
        emoji: '🖼️',
        name: 'Persi · Noon',
        description: 'Equip this noon background for feed.',
        price: 200,
        color: Color(0xFFEADFFF),
        imageAsset: 'assets/packs/feed/persinoon.png',
        equipSlot: 'background_feed',
        backgroundItem: true),
    ShopItem(
        id: 'background_feed_persi_night',
        category: 'Feed',
        emoji: '🖼️',
        name: 'Persi · Night',
        description: 'Equip this night background for feed.',
        price: 200,
        color: Color(0xFFEADFFF),
        imageAsset: 'assets/packs/feed/persinight.png',
        equipSlot: 'background_feed',
        backgroundItem: true),
    ShopItem(
        id: 'background_feed_clearfeed_morning',
        category: 'Feed',
        emoji: '🖼️',
        name: 'Clear Feed · Morning',
        description: 'Equip this morning background for feed.',
        price: 200,
        color: Color(0xFFEADFFF),
        imageAsset: 'assets/packs/feed/clearfeed.png',
        equipSlot: 'background_feed',
        backgroundItem: true),
    ShopItem(
        id: 'background_feed_clearfeed_noon',
        category: 'Feed',
        emoji: '🖼️',
        name: 'Clear Feed · Noon',
        description: 'Equip this noon background for feed.',
        price: 200,
        color: Color(0xFFEADFFF),
        imageAsset: 'assets/packs/feed/clearfeednoon.png',
        equipSlot: 'background_feed',
        backgroundItem: true),
    ShopItem(
        id: 'background_feed_clearfeed_night',
        category: 'Feed',
        emoji: '🖼️',
        name: 'Clear Feed · Night',
        description: 'Equip this night background for feed.',
        price: 200,
        color: Color(0xFFEADFFF),
        imageAsset: 'assets/packs/feed/clearfeednight.png',
        equipSlot: 'background_feed',
        backgroundItem: true),
    ShopItem(
        id: 'background_feed_aesthicfeed_morning',
        category: 'Feed',
        emoji: '🖼️',
        name: 'Aesthetic Feed · Morning',
        description: 'Equip this morning background for feed.',
        price: 200,
        color: Color(0xFFEADFFF),
        imageAsset: 'assets/packs/feed/aesthicfeed.png',
        equipSlot: 'background_feed',
        backgroundItem: true),
    ShopItem(
        id: 'background_feed_aesthicfeed_noon',
        category: 'Feed',
        emoji: '🖼️',
        name: 'Aesthetic Feed · Noon',
        description: 'Equip this noon background for feed.',
        price: 200,
        color: Color(0xFFEADFFF),
        imageAsset: 'assets/packs/feed/aesthicfeednoon.png',
        equipSlot: 'background_feed',
        backgroundItem: true),
    ShopItem(
        id: 'background_feed_aesthicfeed_night',
        category: 'Feed',
        emoji: '🖼️',
        name: 'Aesthetic Feed · Night',
        description: 'Equip this night background for feed.',
        price: 200,
        color: Color(0xFFEADFFF),
        imageAsset: 'assets/packs/feed/aesthicfeednight.png',
        equipSlot: 'background_feed',
        backgroundItem: true),
    ShopItem(
        id: 'background_groom_richgroom_morning',
        category: 'Grooming',
        emoji: '🖼️',
        name: 'Rich Groom · Morning',
        description: 'Equip this morning background for grooming.',
        price: 200,
        color: Color(0xFFEADFFF),
        imageAsset: 'assets/packs/groom/richgroom.png',
        equipSlot: 'background_groom',
        backgroundItem: true),
    ShopItem(
        id: 'background_groom_richgroom_noon',
        category: 'Grooming',
        emoji: '🖼️',
        name: 'Rich Groom · Noon',
        description: 'Equip this noon background for grooming.',
        price: 200,
        color: Color(0xFFEADFFF),
        imageAsset: 'assets/packs/groom/richgroomnoon.png',
        equipSlot: 'background_groom',
        backgroundItem: true),
    ShopItem(
        id: 'background_groom_richgroom_night',
        category: 'Grooming',
        emoji: '🖼️',
        name: 'Rich Groom · Night',
        description: 'Equip this night background for grooming.',
        price: 200,
        color: Color(0xFFEADFFF),
        imageAsset: 'assets/packs/groom/richgroomnight.png',
        equipSlot: 'background_groom',
        backgroundItem: true),
    ShopItem(
        id: 'background_groom_freshgroom_morning',
        category: 'Grooming',
        emoji: '🖼️',
        name: 'Fresh Groom · Morning',
        description: 'Equip this morning background for grooming.',
        price: 200,
        color: Color(0xFFEADFFF),
        imageAsset: 'assets/packs/groom/freshgroom.png',
        equipSlot: 'background_groom',
        backgroundItem: true),
    ShopItem(
        id: 'background_groom_freshgroom_noon',
        category: 'Grooming',
        emoji: '🖼️',
        name: 'Fresh Groom · Noon',
        description: 'Equip this noon background for grooming.',
        price: 200,
        color: Color(0xFFEADFFF),
        imageAsset: 'assets/packs/groom/freshgroomnoon.png',
        equipSlot: 'background_groom',
        backgroundItem: true),
    ShopItem(
        id: 'background_groom_freshgroom_night',
        category: 'Grooming',
        emoji: '🖼️',
        name: 'Fresh Groom · Night',
        description: 'Equip this night background for grooming.',
        price: 200,
        color: Color(0xFFEADFFF),
        imageAsset: 'assets/packs/groom/freshgroomnight.png',
        equipSlot: 'background_groom',
        backgroundItem: true),
    ShopItem(
        id: 'background_groom_cozygroom_morning',
        category: 'Grooming',
        emoji: '🖼️',
        name: 'Cozy Groom · Morning',
        description: 'Equip this morning background for grooming.',
        price: 200,
        color: Color(0xFFEADFFF),
        imageAsset: 'assets/packs/groom/cozygroom.png',
        equipSlot: 'background_groom',
        backgroundItem: true),
    ShopItem(
        id: 'background_groom_cozygroom_noon',
        category: 'Grooming',
        emoji: '🖼️',
        name: 'Cozy Groom · Noon',
        description: 'Equip this noon background for grooming.',
        price: 200,
        color: Color(0xFFEADFFF),
        imageAsset: 'assets/packs/groom/cozygroomnoon.png',
        equipSlot: 'background_groom',
        backgroundItem: true),
    ShopItem(
        id: 'background_groom_cozygroom_night',
        category: 'Grooming',
        emoji: '🖼️',
        name: 'Cozy Groom · Night',
        description: 'Equip this night background for grooming.',
        price: 200,
        color: Color(0xFFEADFFF),
        imageAsset: 'assets/packs/groom/cozygroomnight.png',
        equipSlot: 'background_groom',
        backgroundItem: true),
    ShopItem(
        id: 'background_play_verdiplay_morning',
        category: 'Play',
        emoji: '🖼️',
        name: 'Verdi Play · Morning',
        description: 'Equip this morning background for play.',
        price: 200,
        color: Color(0xFFEADFFF),
        imageAsset: 'assets/packs/play/verdiplay.png',
        equipSlot: 'background_play',
        backgroundItem: true),
    ShopItem(
        id: 'background_play_verdiplay_noon',
        category: 'Play',
        emoji: '🖼️',
        name: 'Verdi Play · Noon',
        description: 'Equip this noon background for play.',
        price: 200,
        color: Color(0xFFEADFFF),
        imageAsset: 'assets/packs/play/verdiplaynoon.png',
        equipSlot: 'background_play',
        backgroundItem: true),
    ShopItem(
        id: 'background_play_verdiplay_night',
        category: 'Play',
        emoji: '🖼️',
        name: 'Verdi Play · Night',
        description: 'Equip this night background for play.',
        price: 200,
        color: Color(0xFFEADFFF),
        imageAsset: 'assets/packs/play/verdiplaynight.png',
        equipSlot: 'background_play',
        backgroundItem: true),
    ShopItem(
        id: 'background_play_gardenplay_morning',
        category: 'Play',
        emoji: '🖼️',
        name: 'Garden Play · Morning',
        description: 'Equip this morning background for play.',
        price: 200,
        color: Color(0xFFEADFFF),
        imageAsset: 'assets/packs/play/gardenplay.png',
        equipSlot: 'background_play',
        backgroundItem: true),
    ShopItem(
        id: 'background_play_gardenplay_noon',
        category: 'Play',
        emoji: '🖼️',
        name: 'Garden Play · Noon',
        description: 'Equip this noon background for play.',
        price: 200,
        color: Color(0xFFEADFFF),
        imageAsset: 'assets/packs/play/gardenplaynoon.png',
        equipSlot: 'background_play',
        backgroundItem: true),
    ShopItem(
        id: 'background_play_gardenplay_night',
        category: 'Play',
        emoji: '🖼️',
        name: 'Garden Play · Night',
        description: 'Equip this night background for play.',
        price: 200,
        color: Color(0xFFEADFFF),
        imageAsset: 'assets/packs/play/gardenplaynigth.png',
        equipSlot: 'background_play',
        backgroundItem: true),
    ShopItem(
        id: 'background_play_createplay_morning',
        category: 'Play',
        emoji: '🖼️',
        name: 'Create Play · Morning',
        description: 'Equip this morning background for play.',
        price: 200,
        color: Color(0xFFEADFFF),
        imageAsset: 'assets/packs/play/createplay.png',
        equipSlot: 'background_play',
        backgroundItem: true),
    ShopItem(
        id: 'background_play_createplay_noon',
        category: 'Play',
        emoji: '🖼️',
        name: 'Create Play · Noon',
        description: 'Equip this noon background for play.',
        price: 200,
        color: Color(0xFFEADFFF),
        imageAsset: 'assets/packs/play/createplaynoon.png',
        equipSlot: 'background_play',
        backgroundItem: true),
    ShopItem(
        id: 'background_play_createplay_night',
        category: 'Play',
        emoji: '🖼️',
        name: 'Create Play · Night',
        description: 'Equip this night background for play.',
        price: 200,
        color: Color(0xFFEADFFF),
        imageAsset: 'assets/packs/play/createplaynight.png',
        equipSlot: 'background_play',
        backgroundItem: true),
    ShopItem(
        id: 'medicine_consumable',
        category: 'Care',
        emoji: '💊',
        name: 'Cat Medicine',
        description: 'For your sick virtual Persian cat.',
        price: 10,
        color: Color(0xFFFFE4D6)),
    ShopItem(
        id: 'persian_vaccine_consumable',
        category: 'Care',
        emoji: '💉',
        name: 'Persian Cat Vaccine',
        description: 'Vaccine item for your virtual Persian cat.',
        price: 10,
        color: Color(0xFFE4F0FF)),
  ];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _categories.length, vsync: this);
    _catProgress.addListener(_onCatProgressChanged);
  }

  void _onCatProgressChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _catProgress.removeListener(_onCatProgressChanged);
    _tabs.dispose();
    super.dispose();
  }

  List<ShopItem> _itemsFor(String category) {
    if (category == 'All Rooms') {
      final slot = 'background_${_selectedRoom.toLowerCase()}';
      final time = _selectedTime.toLowerCase();
      return _items.where((item) {
        if (!item.backgroundItem || item.equipSlot != slot) return false;
        return item.name.toLowerCase().endsWith(time);
      }).toList();
    }
    if (category == 'Care')
      return _items.where((item) => item.category == 'Care').toList();
    final itemCategory = category == 'Decor' ? 'Room Decor' : category;
    return _items
        .where((item) => !item.backgroundItem && item.category == itemCategory)
        .toList();
  }

  int _requiredLevelForCategory(String category) => switch (category) {
        'Grooming' || 'Feed' || 'Play' => 5,
        'Decor' => 7,
        'Care' => 1,
        'All Rooms' => 10,
        _ => 1,
      };

  Future<void> _buy(ShopItem item) async {
    if (item.id == 'medicine_consumable' ||
        item.id == 'persian_vaccine_consumable') {
      final rewards = context.read<RewardService>();
      final price = item.id == 'medicine_consumable'
          ? RewardService.medicinePrice
          : RewardService.vaccinePrice;
      if (rewards.points < price) {
        showPersipalSnackBar(
            context, 'You need ${price - rewards.points} more points.',
            color: AppTheme.softBrown, icon: Icons.lock_outline);
        return;
      }
      final purchased = item.id == 'medicine_consumable'
          ? await rewards.purchaseMedicine()
          : await rewards.purchaseVaccine();
      if (!mounted) return;
      if (purchased) {
        showPersipalSnackBar(
          context,
          item.id == 'medicine_consumable'
              ? 'Medicine added to your Care Bag! 💊'
              : 'Persian Cat Vaccine added to your Care Bag! 💉',
          color: AppTheme.teal,
          icon: Icons.check_circle_outline,
        );
      }
      return;
    }
    final category = item.category == 'Room Decor'
        ? 'Decor'
        : (item.backgroundItem ? 'All Rooms' : item.category);
    final requiredLevel = _requiredLevelForCategory(category);
    if (_catProgress.level < requiredLevel) {
      showPersipalSnackBar(
        context,
        'Reach virtual cat Level $requiredLevel to unlock $category.',
        color: AppTheme.softBrown,
        icon: Icons.lock_outline,
      );
      return;
    }

    final rewards = context.read<RewardService>();
    if (rewards.isShopItemPurchased(item.id)) return;

    if (rewards.points < item.price) {
      showPersipalSnackBar(
        context,
        'You need ${item.price - rewards.points} more points.',
        color: AppTheme.softBrown,
        icon: Icons.lock_outline,
      );
      return;
    }

    final purchased = await rewards.purchaseShopItem(item.id, item.price);
    if (!mounted) return;

    if (purchased) {
      await rewards.equipShopItem(
          item.id,
          item.equipSlot ??
              'item_${item.category.toLowerCase().replaceAll(' ', '_')}');
      if (!mounted) return;
      showPersipalSnackBar(
        context,
        '${item.name} purchased! 🎉',
        color: AppTheme.teal,
        icon: Icons.check_circle_outline,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final rewards = context.watch<RewardService>();

    return Scaffold(
      backgroundColor: AppTheme.cream,
      body: Stack(
        children: [
          const PawBackground(opacity: 0.10),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 6, 16, 8),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                        color: AppTheme.darkBrown,
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Text('🛍️', style: TextStyle(fontSize: 21)),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Persipal Shop',
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.darkBrown,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.86),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppTheme.gold.withValues(alpha: 0.30),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('⭐', style: TextStyle(fontSize: 16)),
                            const SizedBox(width: 5),
                            Text(
                              '${rewards.points}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.darkBrown,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 2, 16, 0),
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7F0),
                    borderRadius: BorderRadius.circular(22),
                    border:
                        Border.all(color: const Color(0xFFF0D8C6), width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF9D6C4A).withValues(alpha: 0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFE4D2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.auto_awesome_rounded,
                                color: Color(0xFFB87953), size: 19),
                          ),
                          const SizedBox(width: 9),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Find a little something',
                                    style: TextStyle(
                                      color: AppTheme.darkBrown,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                    )),
                                SizedBox(height: 2),
                                Text('Tools, decor & cozy room backgrounds',
                                    style: TextStyle(
                                      color: AppTheme.softBrown,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                    )),
                              ],
                            ),
                          ),
                          const Text('🐾', style: TextStyle(fontSize: 21)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5E5D8),
                          borderRadius: BorderRadius.circular(17),
                        ),
                        child: TabBar(
                          controller: _tabs,
                          isScrollable: true,
                          tabAlignment: TabAlignment.start,
                          labelColor: AppTheme.darkBrown,
                          unselectedLabelColor: AppTheme.softBrown,
                          indicatorSize: TabBarIndicatorSize.tab,
                          indicator: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(13),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF96694B)
                                    .withValues(alpha: 0.10),
                                blurRadius: 5,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          dividerColor: Colors.transparent,
                          labelStyle: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                          unselectedLabelStyle: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                          tabs: const [
                            Tab(
                                icon: Icon(Icons.cleaning_services_rounded,
                                    size: 15),
                                text: 'Grooming'),
                            Tab(
                                icon: Icon(Icons.restaurant_rounded, size: 15),
                                text: 'Feed'),
                            Tab(
                                icon: Icon(Icons.sports_esports_rounded,
                                    size: 15),
                                text: 'Play'),
                            Tab(
                                icon: Icon(Icons.weekend_rounded, size: 15),
                                text: 'Decor'),
                            Tab(
                                icon: Icon(Icons.home_work_rounded, size: 15),
                                text: 'All Rooms'),
                            Tab(
                                icon: Icon(Icons.medical_services_rounded,
                                    size: 15),
                                text: 'Care'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: TabBarView(
                    controller: _tabs,
                    children: _categories
                        .map((category) => _buildCategory(
                              category,
                              rewards,
                            ))
                        .toList(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLockedCategory(String category, int requiredLevel) {
    final remaining = requiredLevel - _catProgress.level;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 340),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.90),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppTheme.gold.withValues(alpha: 0.35)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_rounded,
                  size: 46, color: AppTheme.softBrown),
              const SizedBox(height: 12),
              Text('$category is locked',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.darkBrown)),
              const SizedBox(height: 8),
              Text(
                  'Reach virtual cat Level $requiredLevel to unlock this shop section.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 13, height: 1.4, color: AppTheme.softBrown)),
              const SizedBox(height: 16),
              Text('Current level: ${_catProgress.level}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, color: AppTheme.darkBrown)),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: (_catProgress.level / requiredLevel).clamp(0.0, 1.0),
                  minHeight: 9,
                  backgroundColor: const Color(0xFFF5E5D8),
                  valueColor: const AlwaysStoppedAnimation(AppTheme.gold),
                ),
              ),
              const SizedBox(height: 8),
              Text('$remaining more level${remaining == 1 ? '' : 's'} to go!',
                  style:
                      const TextStyle(fontSize: 12, color: AppTheme.softBrown)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategory(String category, RewardService rewards) {
    final items = _itemsFor(category);
    final itemList = ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = items[index];
        final isMedicine = item.id == 'medicine_consumable';
        final owned = !isMedicine && rewards.isShopItemPurchased(item.id);
        final slot = item.equipSlot ??
            'item_${item.category.toLowerCase().replaceAll(' ', '_')}';
        final equipped = rewards.equippedShopItem(slot) == item.id;
        final canBuy = rewards.points >= item.price;
        final itemCategory = item.category == 'Room Decor'
            ? 'Decor'
            : (item.backgroundItem ? 'All Rooms' : item.category);
        final itemRequiredLevel = _requiredLevelForCategory(itemCategory);
        final itemLocked = _catProgress.level < itemRequiredLevel;

        return GestureDetector(
          onTap: itemLocked
              ? () => showPersipalSnackBar(
                    context,
                    'Reach virtual cat Level $itemRequiredLevel to unlock ${item.name}.',
                    color: AppTheme.softBrown,
                    icon: Icons.lock_outline,
                  )
              : null,
          child: Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFCF8),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: item.color.withValues(alpha: 0.95),
                width: 1.4,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF8C6148).withValues(alpha: 0.07),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 66,
                  height: 66,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        item.color,
                        Colors.white.withValues(alpha: 0.72)
                      ],
                    ),
                    borderRadius: BorderRadius.circular(19),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  alignment: Alignment.center,
                  child: Stack(
                    children: [
                      Center(
                        child: item.imageAsset != null
                            ? Image.asset(item.imageAsset!,
                                width: 42, height: 42, fit: BoxFit.contain)
                            : Text(item.emoji,
                                style: const TextStyle(fontSize: 32)),
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Icon(
                          itemLocked
                              ? Icons.lock_rounded
                              : Icons.auto_awesome_rounded,
                          size: itemLocked ? 16 : 12,
                          color: itemLocked
                              ? AppTheme.darkBrown
                              : AppTheme.darkBrown.withValues(alpha: 0.45),
                        ),
                      ),
                      if (itemLocked)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppTheme.darkBrown.withValues(alpha: 0.20),
                              borderRadius: BorderRadius.circular(17),
                            ),
                            child: const Center(
                              child: Icon(Icons.lock_rounded,
                                  size: 23, color: Colors.white),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.darkBrown,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10,
                          height: 1.25,
                          color: AppTheme.softBrown,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (!owned)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFE9C9),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('⭐', style: TextStyle(fontSize: 11)),
                              const SizedBox(width: 4),
                              Text(
                                '${item.price} points',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  color: AppTheme.darkBrown,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.teal.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            equipped ? '✓ EQUIPPED' : '✓ OWNED',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.teal,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (owned && !itemLocked)
                  SizedBox(
                    width: 68,
                    child: equipped
                        ? Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                                color: AppTheme.teal.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(14)),
                            child: const Icon(Icons.check_rounded,
                                color: AppTheme.teal, size: 21),
                          )
                        : ElevatedButton(
                            onPressed: () async {
                              await rewards.equipShopItem(item.id, slot);
                            },
                            style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.teal,
                                foregroundColor: Colors.white,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14))),
                            child: const Text('EQUIP',
                                style: TextStyle(
                                    fontSize: 9, fontWeight: FontWeight.w900)),
                          ),
                  )
                else
                  SizedBox(
                    width: 66,
                    child: ElevatedButton(
                      onPressed: itemLocked
                          ? () => showPersipalSnackBar(
                                context,
                                'Reach virtual cat Level $itemRequiredLevel to unlock ${item.name}.',
                                color: AppTheme.softBrown,
                                icon: Icons.lock_outline,
                              )
                          : ((owned && !isMedicine)
                              ? null
                              : (canBuy ? () => _buy(item) : null)),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        elevation: canBuy ? 2 : 0,
                        shadowColor: AppTheme.salmon.withValues(alpha: 0.3),
                        backgroundColor: AppTheme.salmon,
                        disabledBackgroundColor: const Color(0xFFE9DFD8),
                        foregroundColor: Colors.white,
                        disabledForegroundColor: AppTheme.softBrown,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                          itemLocked
                              ? 'LOCKED'
                              : (owned
                                  ? 'OWNED'
                                  : (isMedicine ? 'BUY' : 'BUY')),
                          style: const TextStyle(
                            fontSize: 10,
                            letterSpacing: 0.7,
                            fontWeight: FontWeight.w900,
                          )),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );

    if (category != 'All Rooms') return itemList;

    Widget filterPill(String label, bool selected, VoidCallback onTap) {
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              decoration: BoxDecoration(
                color: selected ? Colors.white : const Color(0xFFF5E5D8),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color:
                      selected ? const Color(0xFFE8CBB7) : Colors.transparent,
                ),
              ),
              child: Center(
                child: Text(label,
                    style: TextStyle(
                      color: selected ? AppTheme.darkBrown : AppTheme.softBrown,
                      fontSize: 11,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    )),
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF7F0),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFF0D8C6)),
          ),
          child: Row(
            children: _roomTypes
                .map((room) => filterPill(
                      room,
                      _selectedRoom == room,
                      () => setState(() {
                        _selectedRoom = room;
                      }),
                    ))
                .toList(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              const Icon(Icons.wb_sunny_outlined,
                  size: 16, color: Color(0xFFB87953)),
              const SizedBox(width: 6),
              const Text('Time of day',
                  style: TextStyle(
                    color: AppTheme.darkBrown,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  )),
              const SizedBox(width: 8),
              Expanded(
                child: Row(
                  children: _times
                      .map((time) => filterPill(
                            time,
                            _selectedTime == time,
                            () => setState(() {
                              _selectedTime = time;
                            }),
                          ))
                      .toList(),
                ),
              ),
            ],
          ),
        ),
        Expanded(child: itemList),
      ],
    );
  }
}

class ShopItem {
  final String id;
  final String category;
  final String emoji;
  final String name;
  final String description;
  final int price;
  final Color color;
  final String? imageAsset;
  final String? equipSlot;
  final bool backgroundItem;

  const ShopItem({
    required this.id,
    required this.category,
    required this.emoji,
    required this.name,
    required this.description,
    required this.price,
    required this.color,
    this.imageAsset,
    this.equipSlot,
    this.backgroundItem = false,
  });
}
