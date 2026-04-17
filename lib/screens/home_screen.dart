import 'package:flutter/material.dart';
import 'game_screen.dart';
import 'learn_screen.dart';
import 'reminder_screen.dart';
import 'tap_effects.dart'; // 👈 IMPORTANT for BounceButton

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFE6CC),

      body: Stack(
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
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 🐾 HEADER
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.menu, size: 28),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Menu clicked")),
                          );
                        },
                      ),

                      const Row(
                        children: [
                          Icon(Icons.pets, size: 28),
                          SizedBox(width: 6),
                          Text(
                            "PERSIPAL",
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),

                      IconButton(
                        icon: const Icon(Icons.settings, size: 26),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Settings opened")),
                          );
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        "Your interactive Persian cat care learning platform",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 25),

                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Text(
                      "Learn, simulate, and manage Persian cat care in one app. "
                      "Understand your pet's daily routines easily.",
                      style: TextStyle(fontSize: 13),
                    ),
                  ),

                  const SizedBox(height: 25),

                  const Text(
                    "Explore Modules",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 15),

                  // 🎮 VIRTUAL CAT MODULE
                  _buildBounceTile(
                    context,
                    icon: Icons.pets,
                    title: "Virtual Cat Simulation",
                    subtitle: "Interact with your virtual cat",
                    page: const GameScreen(),
                  ),

                  const SizedBox(height: 10),

                  // 📚 LEARNING MODULE
                  _buildBounceTile(
                    context,
                    icon: Icons.menu_book,
                    title: "Educational Lessons",
                    subtitle: "Learn brushing, trimming, nutrition & behavior",
                    page: const LearnScreen(),
                  ),

                  const SizedBox(height: 10),

                  // ⏰ REMINDER MODULE
                  _buildBounceTile(
                    context,
                    icon: Icons.alarm,
                    title: "Care Reminders",
                    subtitle: "Set feeding, grooming, vitamin schedules, etc.",
                    page: const ReminderScreen(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBounceTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget page,
  }) {
    return BounceButton(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => page));
      },
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.75),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            Icon(icon, size: 30, color: Colors.black),
            const SizedBox(width: 15),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(subtitle, style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),

            const Icon(Icons.arrow_forward_ios, size: 16),
          ],
        ),
      ),
    );
  }
}
