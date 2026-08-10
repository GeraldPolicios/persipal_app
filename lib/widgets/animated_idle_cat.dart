import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AnimatedIdleCat extends StatefulWidget {
  const AnimatedIdleCat({
    super.key,
    this.height = 80,
  });

  final double height;

  @override
  State<AnimatedIdleCat> createState() => _AnimatedIdleCatState();
}

class _AnimatedIdleCatState extends State<AnimatedIdleCat> {
  static const int totalFrames = 141;

  final List<Image> _frames = [];

  int _frame = 0;

  bool _loaded = false;

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadFrames();
  }

  Future<void> _loadFrames() async {
    for (int i = 1; i <= totalFrames; i++) {
      final bytes = await rootBundle.load(
        'assets/images/idle_cat/frame_${i.toString().padLeft(4, '0')}.png',
      );

      _frames.add(
        Image.memory(
          bytes.buffer.asUint8List(),
          gaplessPlayback: true,
          filterQuality: FilterQuality.high,
        ),
      );
    }

    if (!mounted) return;

    setState(() {
      _loaded = true;
    });

    _timer = Timer.periodic(
      const Duration(milliseconds: 60),
      (_) {
        if (!mounted) return;

        setState(() {
          _frame = (_frame + 1) % totalFrames;
        });
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return SizedBox(
        height: widget.height,
      );
    }

    return SizedBox(
      height: widget.height,
      child: _frames[_frame],
    );
  }
}
