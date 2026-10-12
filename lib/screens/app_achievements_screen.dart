import 'package:flutter/material.dart';
import '../services/app_achievement_service.dart';
import '../services/reward_service.dart';
import '../themes/app_theme.dart';

class AppAchievementsScreen extends StatefulWidget {
  const AppAchievementsScreen({super.key});
  @override
  State<AppAchievementsScreen> createState() => _AppAchievementsScreenState();
}

class _AppAchievementsScreenState extends State<AppAchievementsScreen> {
  final _service = AppAchievementService.instance;
  final _rewards = RewardService.instance;
  @override
  void initState() {
    super.initState();
    _service.addListener(_refresh);
    _rewards.addListener(_refresh);
  }

  @override
  void dispose() {
    _service.removeListener(_refresh);
    _rewards.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final list = _service.achievements;
    return Scaffold(
      backgroundColor: AppTheme.cream,
      appBar: AppBar(
          backgroundColor: AppTheme.cream,
          title: const Text('🌟 App Achievements')),
      body: Column(children: [
        Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(16)),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        '${_service.unlockedCount} / ${_service.totalCount} unlocked',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                        value: _service.totalCount == 0
                            ? 0
                            : _service.unlockedCount / _service.totalCount),
                    const SizedBox(height: 6),
                    Text('Coins available: ${_rewards.points}',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    const Text(
                        'Rewards are added automatically when requirements are met and can only be paid once.',
                        style: TextStyle(fontSize: 12, color: Colors.black54)),
                  ]),
            )),
        Expanded(
            child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                itemCount: list.length,
                itemBuilder: (context, i) {
                  final a = list[i];
                  final progress = _service.progress(a).clamp(0, a.target);
                  final unlocked = _service.isUnlocked(a);
                  return Card(
                      color: Colors.white,
                      margin: const EdgeInsets.only(bottom: 9),
                      child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(children: [
                            Container(
                                width: 48,
                                height: 48,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                    color: unlocked
                                        ? const Color(0xFFFFE7A3)
                                        : const Color(0xFFF2EEE8),
                                    borderRadius: BorderRadius.circular(14)),
                                child: Text(a.emoji,
                                    style: const TextStyle(fontSize: 25))),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text(a.title,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 2),
                                  Text(a.description,
                                      style: const TextStyle(
                                          fontSize: 12, color: Colors.black54)),
                                  const SizedBox(height: 7),
                                  LinearProgressIndicator(
                                      value: progress / a.target),
                                  const SizedBox(height: 3),
                                  Text(
                                      '$progress / ${a.target} • ${unlocked ? 'Completed' : 'In progress'}',
                                      style: const TextStyle(
                                          fontSize: 11, color: Colors.black54)),
                                ])),
                            const SizedBox(width: 8),
                            Column(children: [
                              const Icon(Icons.monetization_on,
                                  color: Color(0xFFE4AC28)),
                              Text('+${a.coins}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12))
                            ]),
                          ])));
                }))
      ]),
    );
  }
}
