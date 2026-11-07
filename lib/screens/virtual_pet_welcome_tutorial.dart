import 'package:flutter/material.dart';

/// Six-slide, centered walkthrough for first-time PersiPal players.
/// The live Game Screen remains visible behind the translucent overlay.
class VirtualPetWelcomeTutorial extends StatefulWidget {
  final VoidCallback onComplete;

  const VirtualPetWelcomeTutorial({
    super.key,
    required this.onComplete,
  });

  @override
  State<VirtualPetWelcomeTutorial> createState() =>
      _VirtualPetWelcomeTutorialState();
}

class _VirtualPetWelcomeTutorialState extends State<VirtualPetWelcomeTutorial> {
  int _page = 0;

  static const Color _brown = Color(0xFF76513B);
  static const Color _muted = Color(0xFF927662);
  static const Color _coral = Color(0xFFFF9678);
  static const Color _cream = Color(0xFFFFFBF6);

  static const List<_TutorialSlide> _slides = [
    _TutorialSlide(
      title: 'Meet Your Virtual Pet',
      subtitle: 'Your virtual Persian cat',
      description:
          'Welcome to your virtual Persian cat’s room! You are in charge of keeping your cat happy, clean, fed, and healthy. The Game Screen is your main place to check your pet and choose the care it needs.',
      steps: [
        'Look at your cat and tap it to interact.',
        'Use Feed, Groom, Play, and Status to open each activity.',
        'Check the room clock to see the current in-game time.',
      ],
      tip:
          'Watch your pet’s needs. Its status can change as time passes and as you provide care.',
      emoji: '🐱',
      accent: Color(0xFFFFE3D5),
      icon: Icons.touch_app_rounded,
    ),
    _TutorialSlide(
      title: 'Feed Your Pet',
      subtitle: 'Keep your pet well-fed',
      description:
          'The Feed screen lets you choose food for your virtual cat. You can view the available food items and choose what suits your pet’s needs.',
      steps: [
        'Tap Feed on the Game Screen.',
        'Choose an available food item, such as dry food or wet food.',
        'Drag the food and drop it onto your cat to feed it.',
        'Check your pet’s Hunger status afterward.',
      ],
      tip:
          'Only give your pet suitable food. If an item is unsafe, follow the warning shown in the app.',
      emoji: '🍗',
      accent: Color(0xFFFFE9C9),
      icon: Icons.restaurant_rounded,
    ),
    _TutorialSlide(
      title: 'Groom Your Pet',
      subtitle: 'Keep your pet’s fur clean and neat',
      description:
          'The Groom screen contains care actions for your cat’s coat. You can clean its fur, brush it, and trim it when it is ready.',
      steps: [
        'Tap Groom on the Game Screen.',
        'Choose the cleaning tool when your cat’s fur is dirty.',
        'Drag or swipe the brush over your cat to brush its fur.',
        'When the fur is clean, choose Trim if you want to trim it.',
      ],
      tip:
          'Clean dirty fur first. Some grooming actions become available only after your cat is clean.',
      emoji: '🪮',
      accent: Color(0xFFE8E2FF),
      icon: Icons.cleaning_services_rounded,
      useBrushAsset: true,
    ),
    _TutorialSlide(
      title: 'Play Together',
      subtitle: 'Keep your pet happy and active',
      description:
          'The Play screen lets you spend time with your virtual cat using its toys. Playing helps your pet stay happy, but remember that it also needs enough energy to rest.',
      steps: [
        'Tap Play on the Game Screen.',
        'Choose one of the available toys.',
        'Drag the toy and drop it onto your cat to start playing.',
        'Check your pet’s Happiness and Energy after playtime.',
      ],
      tip:
          'If your cat is too hungry or needs cleaning, take care of that need before trying to play.',
      emoji: '🧶',
      accent: Color(0xFFDDF5F0),
      icon: Icons.sports_esports_rounded,
    ),
    _TutorialSlide(
      title: 'Check His Care',
      subtitle: 'Monitor his needs and health',
      description:
          'Use Status to review your pet’s four care indicators. The Care Bag keeps care items together, while Virtual Reminders help you remember regular care tasks.',
      steps: [
        'Tap Status to check Hunger, Happiness, Cleanliness, and Energy.',
        'Tap Care Bag to view your available care items, such as medicine and vaccines.',
        'Tap Reminders to manage care reminders, including feeding, grooming, and health checks.',
        'When your cat is sick, check its health and use the appropriate care item.',
      ],
      tip:
          'Check your pet’s status regularly so you can respond to its needs before they become urgent.',
      emoji: '❤️',
      accent: Color(0xFFFFE0E5),
      icon: Icons.health_and_safety_rounded,
    ),
    _TutorialSlide(
      title: 'Make His Room Yours',
      subtitle: 'Shop, equip, and customize',
      description:
          'Visit the Shop to browse room backgrounds and decorations. Items you obtain can be equipped to customize your virtual pet’s room.',
      steps: [
        'Tap Shop on the Game Screen.',
        'Browse the available backgrounds and decorations.',
        'Use your coins to purchase an item when you have enough.',
        'Equip an owned item to use it in the room. You can switch and re-equip owned items later.',
      ],
      tip:
          'That’s the tour! You can revisit these activities whenever your pet needs care or you want to customize its room.',
      emoji: '🏡',
      accent: Color(0xFFE5F0FF),
      icon: Icons.storefront_rounded,
    ),
  ];

  void _next() {
    if (_page == _slides.length - 1) {
      widget.onComplete();
      return;
    }
    setState(() => _page++);
  }

  void _back() {
    if (_page > 0) setState(() => _page--);
  }

  @override
  Widget build(BuildContext context) {
    final slide = _slides[_page];

    return Positioned.fill(
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            const Positioned.fill(
              child: ColoredBox(color: Color(0x660F1720)),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxHeight < 690;
                  final horizontalPadding = compact ? 16.0 : 20.0;
                  final cardPadding = compact ? 17.0 : 21.0;
                  final artSize = compact ? 54.0 : 62.0;

                  return Center(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                        vertical: 10,
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 390),
                        child: Container(
                          padding: EdgeInsets.all(cardPadding),
                          decoration: BoxDecoration(
                            color: _cream,
                            borderRadius: BorderRadius.circular(25),
                            border: Border.all(
                              color: const Color(0xFFFFE2D2),
                              width: 1.3,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x55000000),
                                blurRadius: 26,
                                offset: Offset(0, 11),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFE9DF),
                                      borderRadius: BorderRadius.circular(11),
                                    ),
                                    child: const Icon(
                                      Icons.pets_rounded,
                                      color: _coral,
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 9),
                                  const Expanded(
                                    child: Text(
                                      'PERSIPAL WALKTHROUGH',
                                      style: TextStyle(
                                        color: _brown,
                                        fontSize: 10.5,
                                        letterSpacing: 1.05,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: widget.onComplete,
                                    style: TextButton.styleFrom(
                                      foregroundColor: _muted,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 3,
                                      ),
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: const Text(
                                      'Skip',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 11),
                              Row(
                                children: List.generate(
                                  _slides.length,
                                  (index) => Expanded(
                                    child: AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 220),
                                      height: 5,
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 2.5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: index <= _page
                                            ? _coral
                                            : const Color(0xFFEADFD5),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 15),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 220),
                                transitionBuilder: (child, animation) =>
                                    FadeTransition(
                                  opacity: animation,
                                  child: SlideTransition(
                                    position: Tween<Offset>(
                                      begin: const Offset(0.035, 0),
                                      end: Offset.zero,
                                    ).animate(animation),
                                    child: child,
                                  ),
                                ),
                                child: Column(
                                  key: ValueKey<int>(_page),
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: artSize,
                                      height: artSize,
                                      decoration: BoxDecoration(
                                        color: slide.accent,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: slide.useBrushAsset
                                            ? Image.asset(
                                                'assets/images/items/brush.png',
                                                width: compact ? 37 : 43,
                                                height: compact ? 37 : 43,
                                                fit: BoxFit.contain,
                                                errorBuilder: (context, error,
                                                        stackTrace) =>
                                                    const Icon(
                                                  Icons
                                                      .cleaning_services_rounded,
                                                  color: _brown,
                                                  size: 36,
                                                ),
                                              )
                                            : Text(
                                                slide.emoji,
                                                style: TextStyle(
                                                  fontSize: compact ? 33 : 39,
                                                ),
                                              ),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      slide.title,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: _brown,
                                        fontSize: 20,
                                        height: 1.12,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      slide.subtitle,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: _coral,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 9),
                                    Text(
                                      slide.description,
                                      textAlign: TextAlign.left,
                                      style: const TextStyle(
                                        color: _muted,
                                        fontSize: 12,
                                        height: 1.38,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFF2E9),
                                        borderRadius: BorderRadius.circular(15),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'HOW TO USE IT',
                                            style: TextStyle(
                                              color: _brown,
                                              fontSize: 10,
                                              letterSpacing: .8,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                          const SizedBox(height: 7),
                                          ...slide.steps.asMap().entries.map(
                                                (entry) => Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                    bottom: 6,
                                                  ),
                                                  child: Row(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Container(
                                                        width: 19,
                                                        height: 19,
                                                        alignment:
                                                            Alignment.center,
                                                        decoration:
                                                            BoxDecoration(
                                                          color: slide.accent,
                                                          shape:
                                                              BoxShape.circle,
                                                        ),
                                                        child: Text(
                                                          '${entry.key + 1}',
                                                          style:
                                                              const TextStyle(
                                                            color: _brown,
                                                            fontSize: 10,
                                                            fontWeight:
                                                                FontWeight.w900,
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Expanded(
                                                        child: Text(
                                                          entry.value,
                                                          style:
                                                              const TextStyle(
                                                            color: _brown,
                                                            fontSize: 11.5,
                                                            height: 1.3,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 9),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 11,
                                        vertical: 9,
                                      ),
                                      decoration: BoxDecoration(
                                        color: slide.accent.withOpacity(.72),
                                        borderRadius: BorderRadius.circular(13),
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Icon(
                                            slide.icon,
                                            size: 16,
                                            color: _brown,
                                          ),
                                          const SizedBox(width: 7),
                                          Expanded(
                                            child: Text(
                                              'TIP: ${slide.tip}',
                                              style: const TextStyle(
                                                color: _brown,
                                                fontSize: 10.5,
                                                height: 1.3,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  if (_page > 0)
                                    OutlinedButton(
                                      onPressed: _back,
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: _brown,
                                        side: const BorderSide(
                                          color: Color(0xFFE4CDBD),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 15,
                                          vertical: 10,
                                        ),
                                        minimumSize: const Size(0, 38),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                      ),
                                      child: const Text('Back'),
                                    )
                                  else
                                    const SizedBox(width: 60),
                                  const Spacer(),
                                  Text(
                                    '${_page + 1} / ${_slides.length}',
                                    style: const TextStyle(
                                      color: _muted,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const Spacer(),
                                  FilledButton(
                                    onPressed: _next,
                                    style: FilledButton.styleFrom(
                                      backgroundColor: _coral,
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 10,
                                      ),
                                      minimumSize: const Size(0, 38),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: Text(
                                      _page == _slides.length - 1
                                          ? 'Let’s Start'
                                          : 'Next',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TutorialSlide {
  final String title;
  final String subtitle;
  final String description;
  final List<String> steps;
  final String tip;
  final String emoji;
  final Color accent;
  final IconData icon;
  final bool useBrushAsset;

  const _TutorialSlide({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.steps,
    required this.tip,
    required this.emoji,
    required this.accent,
    required this.icon,
    this.useBrushAsset = false,
  });
}
