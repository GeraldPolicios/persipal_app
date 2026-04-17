import 'package:flutter/material.dart';
import 'lesson_detail_screen.dart';
import 'quiz_screen.dart';
import 'tap_effects.dart';

class LearnScreen extends StatelessWidget {
  const LearnScreen({super.key});

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
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 🔙 HEADER
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Learn Cat Care 🐱",
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      IconButton(
                        icon: const Icon(Icons.home),
                        onPressed: () {
                          Navigator.pop(context); // back to Home
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  const Text(
                    "Learn how to properly take care of Persian cats through simple lessons and quizzes.",
                    style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic),
                  ),

                  const SizedBox(height: 15),

                  // 📚 LESSON GRID
                  Expanded(
                    child: GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      children: [
                        lessonCard(
                          context,
                          "Grooming",
                          "✂️",
                          Colors.pink,
                          "grooming",
                        ),
                        lessonCard(
                          context,
                          "Feeding",
                          "🍗",
                          Colors.orange,
                          "feeding",
                        ),
                        lessonCard(
                          context,
                          "Behavior",
                          "🐾",
                          Colors.blue,
                          "behavior",
                        ),
                        lessonCard(
                          context,
                          "Vitamins",
                          "💊",
                          Colors.green,
                          "vitamins",
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  // 🧠 QUIZ BUTTON
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD49BC0),
                        padding: const EdgeInsets.all(14),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const QuizScreen()),
                        );
                      },
                      icon: const Icon(Icons.quiz),
                      label: const Text("Start Quiz"),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // 🏠 BACK TO HOME BUTTON
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget lessonCard(
    BuildContext context,
    String title,
    String emoji,
    Color color,
    String type,
  ) {
    return BounceButton(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => LessonDetailScreen(type: type)),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.25),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 40)),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
