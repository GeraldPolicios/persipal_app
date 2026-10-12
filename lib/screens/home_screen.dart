import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/pet_profile_provider.dart';
import '../providers/reminder_provider.dart';
import '../services/auth_service.dart';
import '../services/connectivity_service.dart';
import '../themes/app_theme.dart';
import '../widgets/shared_widgets.dart';
import '../game/home_idle.dart';
import '../widgets/daily_advice_card.dart';

import 'game_screen.dart';
import 'learn_screen.dart';
import 'reminder_screen.dart';
import 'pet_profile_screen.dart';
import 'settings_screen.dart';
import 'achievements_hub_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final HomeIdleGame _homeIdleGame;

  @override
  void initState() {
    super.initState();
    _homeIdleGame = HomeIdleGame();
  }

  @override
  void dispose() {
    _homeIdleGame.pauseEngine();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthService.instance;
    final isOnline = ConnectivityService.instance.isOnline;

    final pending = context
        .watch<ReminderProvider>()
        .reminders
        .where((reminder) => !reminder.isDone)
        .length;

    // Ensure the locally stored pet profiles are initialized.
    unawaited(PetProfileProvider.instance.init());

    return Scaffold(
      backgroundColor: AppTheme.cream,
      body: Stack(
        children: [
          const PawBackground(),
          SafeArea(
            child: CustomScrollView(
              slivers: [
                // ── App bar ──────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 16, 0),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.pets,
                          size: 28,
                          color: AppTheme.salmon,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'PERSIPAL',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                            color: AppTheme.darkText,
                          ),
                        ),
                        const Spacer(),
                        const SyncStatusBadge(),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(
                            Icons.settings_outlined,
                            size: 24,
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const SettingsScreen(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Offline / guest banner ───────────────────────────────
                if (!isOnline || !auth.isAuthenticated)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                      child: _InfoBanner(
                        isOnline: isOnline,
                        isGuest: !auth.isAuthenticated,
                        onSignIn: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const SettingsScreen(),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                // ── Hero banner ──────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFFFF8C69),
                            Color(0xFFFFB347),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.salmon.withValues(alpha: 0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  auth.isAuthenticated
                                      ? 'Hello, ${auth.currentUser?.displayName?.split(' ').first ?? 'Cat Parent'}! 🐾'
                                      : 'Hello, Cat Parent! 🐾',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Learn, simulate, and manage\n'
                                  'your Persian cat\'s care.',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // ── Flame idle cat ──────────────────────────────
                          SizedBox(
                            width: 96,
                            height: 96,
                            child: GameWidget(
                              game: _homeIdleGame,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // ── Daily cat-care advice ─────────────────────────────────
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(20, 14, 20, 0),
                    child: DailyAdviceCard(),
                  ),
                ),

                // ── Section label ─────────────────────────────────────────
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(20, 20, 20, 10),
                    child: Text(
                      'EXPLORE MODULES',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.4,
                        color: AppTheme.softBrown,
                      ),
                    ),
                  ),
                ),

                // ── Module tiles ──────────────────────────────────────────
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // 1. Care Reminders and Pet Profile — side by side at the top.

                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: ListenableBuilder(
                              listenable: PetProfileProvider.instance,
                              builder: (context, _) {
                                final petCount =
                                    PetProfileProvider.instance.count;

                                return _CompactModuleTile(
                                  icon: '🐾',
                                  title: 'Pet Profile',
                                  subtitle: 'Manage your cat profiles',
                                  color: AppTheme.teal,
                                  badge: petCount > 0 ? '$petCount' : null,
                                  page: const PetProfileScreen(),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _CompactModuleTile(
                              icon: '⏰',
                              title: 'Care Reminders',
                              subtitle: 'Manage care schedules',
                              color: AppTheme.salmon,
                              badge: pending > 0 ? '$pending' : null,
                              page: const ReminderScreen(),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      // 2. Virtual Cat Simulation and Educational Lessons
                      // side by side.
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _CompactModuleTile(
                              icon: '🐱',
                              title: 'Virtual Cat',
                              subtitle: 'Feed, groom and play',
                              color: const Color(0xFFFFB347),
                              page: const GameScreen(),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _CompactModuleTile(
                              icon: '📚',
                              title: 'Educational Lessons',
                              subtitle: 'Grooming, nutrition and behavior',
                              color: AppTheme.lavender,
                              page: const LearnScreen(),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      // 4. Achievements — full width at the bottom.
                      const _ModuleTile(
                        icon: '🏆',
                        title: 'Achievements',
                        subtitle:
                            'Virtual Cat milestones & real-pet care badges',
                        color: Color(0xFFFFB347),
                        page: AchievementsHubScreen(),
                      ),
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Offline / guest information banner ───────────────────────────────────────

class _InfoBanner extends StatelessWidget {
  final bool isOnline;
  final bool isGuest;
  final VoidCallback onSignIn;

  const _InfoBanner({
    required this.isOnline,
    required this.isGuest,
    required this.onSignIn,
  });

  @override
  Widget build(BuildContext context) {
    if (!isOnline) {
      return _banner(
        Icons.wifi_off,
        'Offline Mode — data saved locally.',
        AppTheme.softBrown,
        null,
      );
    }

    if (isGuest) {
      return _banner(
        Icons.person_outline,
        'Guest mode — ',
        AppTheme.softBrown,
        TextButton(
          onPressed: onSignIn,
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: const Size(0, 0),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text(
            'sign in to sync',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.salmon,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _banner(
    IconData icon,
    String text,
    Color color,
    Widget? action,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  text,
                  style: TextStyle(
                    fontSize: 12,
                    color: color,
                  ),
                ),
                if (action != null) action,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Full-width module tile ───────────────────────────────────────────────────

class _ModuleTile extends StatelessWidget {
  final String icon;
  final String title;
  final String subtitle;
  final Color color;
  final Widget page;
  final String? badge;

  const _ModuleTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.page,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return BounceButton(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => page,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Text(
                icon,
                style: const TextStyle(fontSize: 24),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            if (badge != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  badge!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 6),
            ],
            Icon(
              Icons.arrow_forward_ios,
              size: 15,
              color: Colors.grey.withValues(alpha: 0.6),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Compact module tile for side-by-side layout ──────────────────────────────

class _CompactModuleTile extends StatelessWidget {
  final String icon;
  final String title;
  final String subtitle;
  final Color color;
  final Widget page;
  final String? badge;

  const _CompactModuleTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.page,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return BounceButton(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => page,
          ),
        );
      },
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 155),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.82),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    icon,
                    style: const TextStyle(fontSize: 21),
                  ),
                ),
                const Spacer(),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      badge!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 10,
                color: Colors.grey,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Icon(
                Icons.arrow_forward_ios,
                size: 13,
                color: Colors.grey.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
