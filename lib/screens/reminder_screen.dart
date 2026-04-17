import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ReminderScreen extends StatefulWidget {
  const ReminderScreen({super.key});

  @override
  State<ReminderScreen> createState() => _ReminderScreenState();
}

class _ReminderScreenState extends State<ReminderScreen> {
  final TextEditingController titleController = TextEditingController();

  String selectedType = "Feeding";
  DateTime? selectedDateTime;

  final List<Map<String, dynamic>> reminders = [];

  final List<String> types = ["Feeding", "Grooming", "Vitamins", "Exercise"];

  Future<void> pickDateTime() async {
    DateTime? date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );

    if (date == null) return;

    TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (time == null) return;

    setState(() {
      selectedDateTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  void addReminder() {
    if (titleController.text.isEmpty || selectedDateTime == null) return;

    setState(() {
      reminders.add({
        "title": titleController.text,
        "type": selectedType,
        "time": selectedDateTime,
      });

      titleController.clear();
      selectedDateTime = null;
    });
  }

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
                        "Care Reminders ⏰",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // 🧾 TITLE INPUT
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: "Reminder Title",
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // 📌 TYPE DROPDOWN
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(),
                    ),
                    child: DropdownButton<String>(
                      value: selectedType,
                      isExpanded: true,
                      underline: const SizedBox(),
                      items: types.map((type) {
                        return DropdownMenuItem(value: type, child: Text(type));
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedType = value!;
                        });
                      },
                    ),
                  ),

                  const SizedBox(height: 10),

                  // 📅 DATE TIME PICKER
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD49BC0),
                    ),
                    onPressed: pickDateTime,
                    icon: const Icon(Icons.calendar_today),
                    label: Text(
                      selectedDateTime == null
                          ? "Pick Date & Time"
                          : DateFormat(
                              "yyyy-MM-dd – hh:mm a",
                            ).format(selectedDateTime!),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // ➕ ADD BUTTON
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.brown,
                        padding: const EdgeInsets.all(14),
                      ),
                      onPressed: addReminder,
                      child: const Text(
                        "Add Reminder",
                        style: TextStyle(color: Colors.yellow),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 📋 LIST
                  const Text(
                    "Your Reminders",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 10),

                  Expanded(
                    child: ListView.builder(
                      itemCount: reminders.length,
                      itemBuilder: (context, index) {
                        final item = reminders[index];

                        return Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            leading: const Icon(Icons.pets),
                            title: Text(item["title"]),
                            subtitle: Text(
                              "${item["type"]} • ${DateFormat("yyyy-MM-dd – hh:mm a").format(item["time"])}",
                            ),
                          ),
                        );
                      },
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
}
