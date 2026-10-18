import 'dart:convert';

import 'package:flutter/material.dart';

import '../services/local_storage_service.dart';
import '../services/notification_service.dart';

/// Daily reminders for PersiPal's virtual cat. These use their own notification
/// IDs and settings, separate from the real-pet reminder manager.
class VirtualRemindersScreen extends StatefulWidget {
  const VirtualRemindersScreen({super.key});

  @override
  State<VirtualRemindersScreen> createState() => _VirtualRemindersScreenState();
}

class _VirtualRemindersScreenState extends State<VirtualRemindersScreen> {
  static const _brown = Color(0xFF85552F);
  static const _muted = Color(0xFFAA7A51);

  static const _definitions = <String,
      ({
    String emoji,
    String title,
    String body,
    int id,
    int hour,
    int minute
  })>{
    'feeding': (
      emoji: '🍗',
      title: 'Feeding',
      body: 'Check your virtual cat’s hunger and offer a meal if needed.',
      id: NotificationService.virtualFeedReminderId,
      hour: 9,
      minute: 0,
    ),
    'grooming': (
      emoji: '🧼',
      title: 'Grooming',
      body: 'Check whether your virtual cat needs cleaning or brushing.',
      id: NotificationService.virtualGroomReminderId,
      hour: 18,
      minute: 0,
    ),
    'medicine': (
      emoji: '💊',
      title: 'Health check',
      body: 'Check your virtual cat’s health and use medicine if it is sick.',
      id: NotificationService.virtualMedicineReminderId,
      hour: 19,
      minute: 0,
    ),
  };

  final Map<String, bool> _enabled = {
    for (final key in _definitions.keys) key: false
  };
  final Map<String, TimeOfDay> _times = {
    for (final entry in _definitions.entries)
      entry.key: TimeOfDay(hour: entry.value.hour, minute: entry.value.minute),
  };
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final raw = LocalStorageService.instance.fetchVirtualReminderSettings();
      if (raw != null) {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) {
          for (final key in _definitions.keys) {
            final value = decoded[key];
            if (value is Map) {
              _enabled[key] = value['enabled'] as bool? ?? false;
              _times[key] = TimeOfDay(
                hour: ((value['hour'] as num?)?.toInt() ?? _times[key]!.hour)
                    .clamp(0, 23)
                    .toInt(),
                minute:
                    ((value['minute'] as num?)?.toInt() ?? _times[key]!.minute)
                        .clamp(0, 59)
                        .toInt(),
              );
            }
          }
        }
      }
    } catch (_) {
      // Invalid old settings are ignored and safe defaults remain selected.
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _saveSettings() async {
    final data = <String, dynamic>{
      for (final key in _definitions.keys)
        key: {
          'enabled': _enabled[key] ?? false,
          'hour': _times[key]!.hour,
          'minute': _times[key]!.minute,
        },
    };
    await LocalStorageService.instance
        .saveVirtualReminderSettings(jsonEncode(data));
  }

  Future<void> _setEnabled(String key, bool enabled) async {
    setState(() {
      _enabled[key] = enabled;
      _saving = true;
    });
    final definition = _definitions[key]!;
    try {
      if (enabled) {
        final time = _times[key]!;
        await NotificationService.instance.scheduleVirtualDailyReminder(
          notificationId: definition.id,
          title: 'PersiPal • ${definition.title}',
          body: definition.body,
          hour: time.hour,
          minute: time.minute,
        );
      } else {
        await NotificationService.instance
            .cancelVirtualDailyReminder(definition.id);
      }
      await _saveSettings();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(enabled
              ? '${definition.title} reminder enabled.'
              : '${definition.title} reminder turned off.'),
        ));
      }
    } catch (error) {
      if (mounted) {
        setState(() => _enabled[key] = !enabled);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text(
                  'Could not update the reminder. Check notification permission and try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _chooseTime(String key) async {
    final selected = await showTimePicker(
      context: context,
      initialTime: _times[key]!,
      helpText: 'Choose daily reminder time',
    );
    if (selected == null || !mounted) return;

    setState(() {
      _times[key] = selected;
      _saving = true;
    });
    final definition = _definitions[key]!;
    try {
      if (_enabled[key] == true) {
        await NotificationService.instance.scheduleVirtualDailyReminder(
          notificationId: definition.id,
          title: 'PersiPal • ${definition.title}',
          body: definition.body,
          hour: selected.hour,
          minute: selected.minute,
        );
      }
      await _saveSettings();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update the reminder time.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFE7D0),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 560),
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8F0),
                borderRadius: BorderRadius.circular(32),
                boxShadow: const [
                  BoxShadow(
                      color: Color(0x22000000),
                      blurRadius: 18,
                      offset: Offset(0, 8))
                ],
              ),
              child: _loading
                  ? const Center(
                      child: Padding(
                          padding: EdgeInsets.all(30),
                          child: CircularProgressIndicator()))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          const Text('🔔', style: TextStyle(fontSize: 32)),
                          const SizedBox(width: 12),
                          const Expanded(
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                Text('Virtual Reminders',
                                    style: TextStyle(
                                        fontSize: 26,
                                        fontWeight: FontWeight.w800,
                                        color: _brown)),
                                Text('Daily reminders for your virtual cat',
                                    style:
                                        TextStyle(fontSize: 14, color: _muted)),
                              ])),
                          IconButton(
                              tooltip: 'Close',
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.close,
                                  size: 30, color: Color(0xFF654D40))),
                        ]),
                        const SizedBox(height: 20),
                        const Text('CHOOSE YOUR REMINDERS',
                            style: TextStyle(
                                fontSize: 13,
                                letterSpacing: 1.6,
                                fontWeight: FontWeight.w800,
                                color: _muted)),
                        const SizedBox(height: 10),
                        for (final entry in _definitions.entries) ...[
                          _reminderCard(entry.key, entry.value),
                          const SizedBox(height: 10),
                        ],
                        if (_saving)
                          const Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: LinearProgressIndicator(minHeight: 2)),
                        const SizedBox(height: 8),
                        const Text(
                            'Reminders repeat once a day at the time you choose. They are optional and separate from reminders for real pets.',
                            style: TextStyle(
                                color: _brown,
                                height: 1.4,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _reminderCard(
      String key,
      ({
        String emoji,
        String title,
        String body,
        int id,
        int hour,
        int minute
      }) definition) {
    final time = _times[key]!;
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFEBD5BE))),
      child: Column(children: [
        Row(children: [
          Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: const Color(0xFFFFE8D8),
                  borderRadius: BorderRadius.circular(14)),
              child:
                  Text(definition.emoji, style: const TextStyle(fontSize: 25))),
          const SizedBox(width: 11),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(definition.title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: _brown,
                        fontSize: 16)),
                Text(definition.body,
                    style: const TextStyle(
                        color: _muted, fontSize: 12, height: 1.3)),
              ])),
          Switch(
              value: _enabled[key] ?? false,
              onChanged: _saving ? null : (value) => _setEnabled(key, value)),
        ]),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: _saving ? null : () => _chooseTime(key),
            icon: const Icon(Icons.schedule, size: 18),
            label: Text('Daily at ${time.format(context)}'),
            style: TextButton.styleFrom(foregroundColor: _brown),
          ),
        ),
      ]),
    );
  }
}
