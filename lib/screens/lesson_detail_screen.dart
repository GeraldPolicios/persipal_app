import 'package:flutter/material.dart';

class LessonDetailScreen extends StatelessWidget {
  final String type;

  const LessonDetailScreen({super.key, required this.type});

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
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 🔙 BACK BUTTON
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => Navigator.pop(context),
                    ),

                    const SizedBox(height: 10),

                    // 📌 TITLE
                    Text(
                      _getTitle(),
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 15),

                    // 📦 OVERVIEW
                    _buildCard(
                      icon: Icons.info,
                      title: "Overview",
                      content: _getOverview(),
                      color: Colors.blue,
                    ),

                    const SizedBox(height: 12),

                    // 📌 DO'S
                    _buildCard(
                      icon: Icons.check_circle,
                      title: "Do's",
                      content: _getDos(),
                      color: Colors.green,
                    ),

                    const SizedBox(height: 12),

                    // ❌ DON'TS
                    _buildCard(
                      icon: Icons.cancel,
                      title: "Don'ts",
                      content: _getDonts(),
                      color: Colors.red,
                    ),

                    const SizedBox(height: 12),

                    // 💡 TIPS
                    _buildCard(
                      icon: Icons.lightbulb,
                      title: "Tips",
                      content: _getTips(),
                      color: Colors.orange,
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 🧱 MODERN CARD UI
  Widget _buildCard({
    required IconData icon,
    required String title,
    required String content,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(content, style: const TextStyle(fontSize: 14, height: 1.5)),
        ],
      ),
    );
  }

  // 🧠 CONTENT LOGIC

  String _getTitle() {
    switch (type) {
      case "grooming":
        return "Grooming Guide ✂️";
      case "feeding":
        return "Feeding Guide 🍗";
      case "behavior":
        return "Behavior Guide 🐾";
      case "vitamins":
        return "Vitamin Guide 💊";
      default:
        return "Lesson";
    }
  }

  String _getOverview() {
    switch (type) {
      case "grooming":
        return "Persian cats require daily grooming due to their long and thick fur.";
      case "feeding":
        return "Proper nutrition is essential for Persian cat health and longevity.";
      case "behavior":
        return "Understanding cat behavior helps improve communication and bonding.";
      case "vitamins":
        return "Vitamins support immunity, fur health, and bone strength.";
      default:
        return "";
    }
  }

  String _getDos() {
    switch (type) {
      case "grooming":
        return "• Brush fur daily\n• Use soft brush\n• Clean eyes gently";
      case "feeding":
        return "• Use high-quality cat food\n• Provide fresh water\n• Feed in schedule";
      case "behavior":
        return "• Observe body language\n• Give attention daily\n• Respect space";
      case "vitamins":
        return "• Use vet-approved vitamins\n• Follow dosage properly\n• Store properly";
      default:
        return "";
    }
  }

  String _getDonts() {
    switch (type) {
      case "grooming":
        return "• Do not pull tangled fur\n• Avoid harsh brushes";
      case "feeding":
        return "• Avoid chocolate\n• Do not give milk\n• Avoid salty food";
      case "behavior":
        return "• Do not disturb when hiding\n• Avoid shouting";
      case "vitamins":
        return "• Never use human medicine\n• Do not overdose vitamins";
      default:
        return "";
    }
  }

  String _getTips() {
    switch (type) {
      case "grooming":
        return "Grooming also builds trust between owner and cat.";
      case "feeding":
        return "A balanced diet prevents obesity and kidney issues.";
      case "behavior":
        return "A happy cat will often purr and rub against you.";
      case "vitamins":
        return "Consult vet before adding supplements.";
      default:
        return "";
    }
  }
}
