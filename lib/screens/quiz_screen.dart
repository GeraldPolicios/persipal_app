import 'package:flutter/material.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  int score = 0;
  int current = 0;

  final questions = [
    {
      "q": "Best food for Persian cats?",
      "a": ["Milk", "Cat Food", "Chocolate"],
      "correct": 1,
    },
    {
      "q": "How often should you brush fur?",
      "a": ["Daily", "Weekly", "Never"],
      "correct": 0,
    },
    {
      "q": "What shows cat happiness?",
      "a": ["Hissing", "Purring", "Hiding"],
      "correct": 1,
    },
  ];

  void answer(int index) {
    if (index == questions[current]["correct"]) {
      score++;
    }

    setState(() {
      current++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFE6CC),

      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: current < questions.length
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => Navigator.pop(context),
                    ),

                    const SizedBox(height: 20),

                    Text(
                      questions[current]["q"] as String,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 20),

                    ...(questions[current]["a"] as List<String>)
                        .asMap()
                        .entries
                        .map(
                          (e) => Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ElevatedButton(
                              onPressed: () => answer(e.key),
                              child: Text(e.value),
                            ),
                          ),
                        ),
                  ],
                )
              : Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Quiz Done!\nScore: $score/${questions.length}",
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 20),

                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD49BC0),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                        onPressed: () {
                          Navigator.pop(context); // back to LearnScreen
                        },
                        icon: const Icon(Icons.school),
                        label: const Text("Back to Learn Cat Care"),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}
