import 'dart:async';

import 'package:flutter/material.dart';

/// Small real-time clock that follows the device's local time.
///
/// It updates once per second and works on both Android and iOS.
class RealtimeClock extends StatefulWidget {
  const RealtimeClock({super.key});

  @override
  State<RealtimeClock> createState() => _RealtimeClockState();
}

class _RealtimeClockState extends State<RealtimeClock> {
  late DateTime _now;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _now = DateTime.now();
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatTime(DateTime time) {
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';

    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF7E8CF).withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF8A6248).withValues(alpha: 0.65),
          width: 1.2,
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 5,
            offset: Offset(1, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.access_time_rounded,
            size: 14,
            color: Color(0xFF7A4F35),
          ),
          const SizedBox(width: 4),
          Text(
            _formatTime(_now),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Color(0xFF5A4636),
            ),
          ),
        ],
      ),
    );
  }
}
