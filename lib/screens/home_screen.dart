// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/auth_service.dart';
import '../services/connectivity_service.dart';
import '../themes/app_theme.dart';
import '../widgets/shared_widgets.dart';
import 'game_screen.dart';
import 'learn_screen.dart';
import 'reminder_screen.dart';
import 'pet_profile_screen.dart';
import 'settings_screen.dart';
import 'activity_log_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final auth = AuthService.instance;
    final isOnline = ConnectivityService.instance.isOnline;

    final pending = prov.pendingReminderCount;
    final petCount = prov.pets.length;
    final actCount = prov.logs.length;

    return Scaffold(
      backgroundColor: AppTheme.cream,
      body: Stack(
        children: [
          const PawBackground(),
          SafeArea(
            child: CustomScrollView(
              slivers: [
                // ── App bar ────────────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 16, 0),
                    child: Row(
                      children: [
                        const Icon(Icons.pets,
                            size: 28, color: AppTheme.salmon),
                        const SizedBox(width: 8),
                        const Text('PERSIPAL',
                            style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
                                color: AppTheme.darkText)),
                        const Spacer(),
                        const SyncStatusBadge(),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.settings_outlined, size: 24),
                          onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const SettingsScreen())),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Offline / guest banner ──────────────────────────────────────
                if (!isOnline || !auth.isAuthenticated)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                      child: _InfoBanner(
                        isOnline: isOnline,
                        isGuest: !auth.isAuthenticated,
                        onSignIn: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const SettingsScreen())),
                      ),
                    ),
                  ),

                // ── Hero banner ─────────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF8C69), Color(0xFFFFB347)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.salmon.withOpacity(0.35),
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
                                      fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Learn, simulate, and manage\nyour Persian cat\'s care.',
                                  style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                      height: 1.4),
                                ),
                              ],
                            ),
                          ),
                          Image.asset('assets/images/cat_normal_clean.png',
                              height: 80),
                        ],
                      ),
                    ),
                  ),
                ),

                // ── Quick stats ─────────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                    child: Row(
                      children: [
                        _StatCard(
                          value: '$petCount',
                          label: 'Cat Profiles',
                          icon: Icons.account_circle,
                          color: AppTheme.lavender,
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const PetProfileScreen())),
                        ),
                        const SizedBox(width: 10),
                        _StatCard(
                          value: '$pending',
                          label: 'Reminders Due',
                          icon: Icons.alarm,
                          color: AppTheme.salmon,
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const ReminderScreen())),
                        ),
                        const SizedBox(width: 10),
                        _StatCard(
                          value: '$actCount',
                          label: 'Activities',
                          icon: Icons.history,
                          color: AppTheme.teal,
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const ActivityLogScreen())),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Section label ─────────────────────────────────────────────
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(20, 20, 20, 10),
                    child: Text('EXPLORE MODULES',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.4,
                            color: AppTheme.softBrown)),
                  ),
                ),

                // ── Module tiles ──────────────────────────────────────────────
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _ModuleTile(
                        icon: '🐱',
                        title: 'Virtual Cat Simulation',
                        subtitle: 'Feed, groom and play with your virtual cat',
                        color: const Color(0xFFFFB347),
                        page: const GameScreen(),
                      ),
                      const SizedBox(height: 10),
                      _ModuleTile(
                        icon: '📚',
                        title: 'Educational Lessons',
                        subtitle: 'Grooming, nutrition, behavior & more',
                        color: AppTheme.lavender,
                        page: const LearnScreen(),
                      ),
                      const SizedBox(height: 10),
                      _ModuleTile(
                        icon: '⏰',
                        title: 'Care Reminders',
                        subtitle: 'Feeding, grooming, vitamin schedules',
                        color: AppTheme.salmon,
                        badge: pending > 0 ? '$pending' : null,
                        page: const ReminderScreen(),
                      ),
                      const SizedBox(height: 10),
                      _ModuleTile(
                        icon: '🐾',
                        title: 'Pet Profile',
                        subtitle:
                            'Manage your Persian cat\'s profile & details',
                        color: AppTheme.teal,
                        badge: petCount > 0 ? '$petCount' : null,
                        page: const PetProfileScreen(),
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

// ── Sub-widgets ──────────────────────────────────────────────────────────────

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
      return _banner(Icons.wifi_off, 'Offline Mode — data saved locally.',
          AppTheme.softBrown, null);
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
              tapTargetSize: MaterialTapTargetSize.shrinkWrap),
          child: const Text('sign in to sync',
              style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.salmon,
                  fontWeight: FontWeight.bold)),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _banner(IconData icon, String text, Color color, Widget? action) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(text, style: TextStyle(fontSize: 12, color: color)),
            if (action != null) action,
          ],
        ),
      );
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _StatCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.78),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 6,
                  offset: const Offset(0, 2)),
            ],
          ),
          child: Column(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(height: 4),
              Text(value,
                  style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold, color: color)),
              Text(label,
                  style: const TextStyle(fontSize: 9, color: Colors.grey),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

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
      onTap: () =>
          Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.82),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14)),
              child: Center(
                  child: Text(icon, style: const TextStyle(fontSize: 24))),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 3),
                  Text(subtitle,
                      style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),
            if (badge != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    color: color, borderRadius: BorderRadius.circular(12)),
                child: Text(badge!,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 6),
            ],
            Icon(Icons.arrow_forward_ios,
                size: 15, color: Colors.grey.withOpacity(0.6)),
          ],
        ),
      ),
    );
  }
}
