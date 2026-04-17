import 'package:flutter/material.dart';
import 'dart:async';
import 'tap_effects.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  String catName = "Meow Meow";
  Timer? _timer;

  int happiness = 70;
  int hunger = 80;
  int cleanliness = 90;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      askCatName();
    });

    // ⏱ START REAL-TIME DECAY TIMER
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        hunger += 5;
        happiness -= 5;
        cleanliness -= 3;

        hunger = hunger.clamp(0, 100);
        happiness = happiness.clamp(0, 100);
        cleanliness = cleanliness.clamp(0, 100);
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // 🐾 NAME INPUT
  void askCatName() {
    TextEditingController controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Enter your cat's name"),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: "e.g. Mochi"),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  catName = controller.text.isEmpty
                      ? "Meow Meow"
                      : controller.text;
                });
                Navigator.pop(context);
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
  }

  // 🐾 ACTION SYSTEM
  void update(String action) {
    setState(() {
      if (action == "feed") {
        hunger -= 20; // stronger effect
        happiness += 10;
      }

      if (action == "groom") {
        cleanliness += 20;
        happiness += 5;
      }

      if (action == "play") {
        happiness += 20;
        hunger += 10;
      }

      hunger = hunger.clamp(0, 100);
      happiness = happiness.clamp(0, 100);
      cleanliness = cleanliness.clamp(0, 100);
    });
  }

  // 🐾 HEART SYSTEM
  String getHearts() {
    if (happiness > 80) return "❤️ ❤️ ❤️";
    if (happiness > 50) return "❤️ ❤️ 🤍";
    return "❤️ 🤍 🤍";
  }

  // 🐾 EMOTION SYSTEM
  String getCatEmotion() {
    int avg = ((happiness + cleanliness + (100 - hunger)) / 3).round();

    // 👇 STRICT TEST MODE (faster reaction)
    if (avg >= 60) return "happy";
    if (avg >= 30) return "normal";
    return "sad";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFE6CC),

      body: Stack(
        fit: StackFit.expand,
        children: [
          // 🌸 BACKGROUND
          Positioned.fill(
            child: Opacity(
              opacity: 0.12,
              child: Image.asset(
                "assets/images/paws_bg.png",
                fit: BoxFit.cover,
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // TOP BAR
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.home),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Icon(Icons.menu),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // TITLE
                  Text(
                    "Hello $catName!",
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Serif',
                    ),
                  ),

                  const Text(
                    "Take care of your Persian today!",
                    style: TextStyle(fontSize: 16),
                  ),

                  const SizedBox(height: 15),

                  // HEARTS
                  Row(
                    children: [
                      Text("$catName:", style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 10),
                      Text(getHearts(), style: const TextStyle(fontSize: 18)),
                    ],
                  ),

                  const SizedBox(height: 15),

                  // 🐱 CAT AREA
                  Container(
                    width: double.infinity,
                    height: 180,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(color: Colors.black54),
                      image: const DecorationImage(
                        image: AssetImage("assets/images/cat_bg_room.png"),
                        fit: BoxFit.cover,
                      ),
                    ),
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: Image.asset(
                            "assets/images/cat_${getCatEmotion()}.png",
                            key: ValueKey(getCatEmotion()),
                            height: 90,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // BUTTON GRID
                  Expanded(
                    child: GridView.count(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.3,
                      children: [
                        BounceButton(
                          onTap: () => update("feed"),
                          child: buildMenuButton("🍗", "Feed"),
                        ),

                        BounceButton(
                          onTap: () => update("groom"),
                          child: buildMenuButton("✂️", "Groom"),
                        ),

                        BounceButton(
                          onTap: () async {
                            await Future.delayed(
                              const Duration(milliseconds: 120),
                            );

                            if (!mounted) return;
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => StatusScreen(
                                  catName: catName,
                                  hunger: hunger,
                                  happiness: happiness,
                                  cleanliness: cleanliness,
                                ),
                              ),
                            );
                          },
                          child: buildMenuButton("❤️", "Status"),
                        ),

                        BounceButton(
                          onTap: () => update("play"),
                          child: buildMenuButton("🐱", "Play"),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 🔘 BUTTON DESIGN
  Widget buildMenuButton(String emoji, String label) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFD9B3C6),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 26)),
            const SizedBox(height: 5),
            Text(
              label,
              style: const TextStyle(fontSize: 18, fontFamily: 'Serif'),
            ),
          ],
        ),
      ),
    );
  }
}

class StatusScreen extends StatelessWidget {
  final String catName;
  final int hunger;
  final int happiness;
  final int cleanliness;

  const StatusScreen({
    super.key,
    required this.catName,
    required this.hunger,
    required this.happiness,
    required this.cleanliness,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFE6CC),

      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: 0.12,
              child: Image.asset(
                "assets/images/paws_bg.png",
                fit: BoxFit.cover,
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("$catName (2 MONTHS)"),
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  Text(
                    "$catName's STATUS",
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Serif',
                    ),
                  ),

                  const SizedBox(height: 30),

                  buildBar("Hunger", hunger, Colors.grey),
                  buildBar("Happiness", happiness, Colors.pink),
                  buildBar("Cleanliness", cleanliness, Colors.green),

                  const SizedBox(height: 20),

                  Text(
                    "$catName is your virtual Persian cat. Take care of it daily to keep it healthy and happy.",
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildBar(String label, int value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        const SizedBox(height: 5),
        LinearProgressIndicator(
          value: value / 100,
          minHeight: 10,
          backgroundColor: Colors.grey[300],
          valueColor: AlwaysStoppedAnimation(color),
        ),
        const SizedBox(height: 15),
      ],
    );
  }
}
