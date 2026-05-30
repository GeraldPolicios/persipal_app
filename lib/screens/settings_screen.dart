// lib/screens/settings_screen.dart
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/auth_service.dart';
import '../services/firebase_sync_service.dart'
    show
        FirebaseSyncService,
        SyncState; // FIX: only import what's needed, not AppProvider
import '../services/connectivity_service.dart';
import '../themes/app_theme.dart';
import '../widgets/shared_widgets.dart';
import 'activity_log_screen.dart';
import 'login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _auth = AuthService.instance;
  bool _syncing = false;

  // ── Sync ─────────────────────────────────────────────────────────────────

  Future<void> _syncNow() async {
    setState(() => _syncing = true);
    final prov = context.read<AppProvider>();
    final result = await prov.syncNow();
    if (!mounted) return;
    setState(() => _syncing = false);
    showPersipalSnackBar(
      context,
      result.success
          ? 'Synced successfully!'
          : (result.error ?? 'Sync failed.'),
      icon: result.success ? Icons.cloud_done : Icons.cloud_off,
      color: result.success ? AppTheme.teal : Colors.redAccent,
    );
  }

  // ── Export / Import ────────────────────────────────────────────────────────

  Future<void> _exportData() async {
    final prov = context.read<AppProvider>();
    try {
      final data = await prov.exportLocalData();
      final json = const JsonEncoder.withIndent('  ').convert(data);
      if (mounted) {
        showPersipalSnackBar(context,
            'Export complete. ${(json.length / 1024).toStringAsFixed(1)} KB of data.',
            icon: Icons.download_done, color: AppTheme.teal);
      }
    } catch (e) {
      if (mounted) {
        showPersipalSnackBar(context, 'Export failed.', isError: true);
      }
    }
  }

  // ── Clear local data ───────────────────────────────────────────────────────

  Future<void> _confirmClearLocal() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => _confirmDialog(
        ctx,
        title: 'Clear Local Data?',
        body: 'All locally stored pets, reminders, and logs will be deleted. '
            'Cloud data (if signed in) will remain safe.',
        confirmLabel: 'Delete Local Data',
        confirmColor: Colors.redAccent,
      ),
    );
    if (ok != true || !mounted) return;
    await context.read<AppProvider>().clearLocalData();
    if (mounted) {
      showPersipalSnackBar(context, 'Local data cleared.',
          icon: Icons.delete_sweep, color: Colors.redAccent);
    }
  }

  // ── Delete account ─────────────────────────────────────────────────────────

  Future<void> _confirmDeleteAccount() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => _confirmDialog(
        ctx,
        title: 'Delete Account?',
        body: 'This will permanently delete your account and all cloud data. '
            'This cannot be undone.',
        confirmLabel: 'Delete Account',
        confirmColor: Colors.redAccent,
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await FirebaseSyncService.instance.deleteAllCloudData();
      await _auth.deleteAccount();
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        showPersipalSnackBar(
            context,
            e.code == 'requires-recent-login'
                ? 'Please sign out and sign back in before deleting.'
                : _auth.friendlyError(e),
            isError: true);
      }
    }
  }

  // ── Sign out ───────────────────────────────────────────────────────────────

  Future<void> _signOut() async {
    await _auth.signOut();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final prov = context.watch<AppProvider>();
    final isAuth = _auth.isAuthenticated;
    final user = _auth.currentUser;
    final isOnline = ConnectivityService.instance.isOnline;
    // ignore: unused_local_variable  (kept for potential future use in UI)
    final syncState = prov.syncState;

    return Scaffold(
      backgroundColor: AppTheme.cream,
      body: Stack(
        children: [
          const PawBackground(),
          SafeArea(
            child: CustomScrollView(
              slivers: [
                // ── Header ────────────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new, size: 22),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const Icon(Icons.settings_outlined, size: 22),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text('Settings',
                              style: TextStyle(
                                  fontSize: 22, fontWeight: FontWeight.bold)),
                        ),
                        const SyncStatusBadge(),
                      ],
                    ),
                  ),
                ),

                SliverList(
                  delegate: SliverChildListDelegate([
                    const SizedBox(height: 10),

                    // ── Account Section ────────────────────────────────────────
                    _sectionLabel('Account'),
                    if (isAuth) ...[
                      _accountTile(user),
                      _tile(
                        icon: Icons.logout,
                        iconColor: Colors.redAccent,
                        label: 'Sign Out',
                        onTap: _signOut,
                      ),
                      _tile(
                        icon: Icons.delete_forever,
                        iconColor: Colors.redAccent,
                        label: 'Delete Account',
                        subtitle: 'Permanently deletes account & cloud data',
                        onTap: _confirmDeleteAccount,
                      ),
                    ] else ...[
                      _tile(
                        icon: Icons.login,
                        iconColor: AppTheme.teal,
                        label: 'Sign In or Create Account',
                        subtitle: 'Sync your progress across devices',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const LoginScreen()),
                        ),
                      ),
                    ],

                    const SizedBox(height: 6),

                    // ── Sync Section ───────────────────────────────────────────
                    if (isAuth) ...[
                      _sectionLabel('Cloud Sync'),
                      _tile(
                        icon: _syncing ? Icons.sync : Icons.cloud_sync,
                        iconColor: AppTheme.teal,
                        label: _syncing ? 'Syncing…' : 'Sync Now',
                        subtitle: prov.lastSyncAt != null
                            ? 'Last synced: ${_timeAgo(prov.lastSyncAt!)}'
                            : isOnline
                                ? 'Tap to sync with cloud'
                                : 'Offline',
                        trailing: _syncing
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: AppTheme.teal))
                            : null,
                        onTap: isOnline && !_syncing ? _syncNow : null,
                      ),
                      const SizedBox(height: 6),
                    ],

                    // ── Preferences ────────────────────────────────────────────
                    _sectionLabel('Preferences'),
                    _switchTile(
                      icon: Icons.notifications_outlined,
                      iconColor: AppTheme.gold,
                      label: 'Notifications',
                      value: prov.settings.notificationsEnabled,
                      // FIX: AppSettings is immutable — use copyWith instead of cascade mutation
                      onChanged: (v) => prov.updateSettings(
                        prov.settings.copyWith(notificationsEnabled: v),
                      ),
                    ),
                    _switchTile(
                      icon: Icons.volume_up_outlined,
                      iconColor: AppTheme.lavender,
                      label: 'Sound Effects',
                      value: prov.settings.soundEnabled,
                      // FIX: AppSettings is immutable — use copyWith instead of cascade mutation
                      onChanged: (v) => prov.updateSettings(
                        prov.settings.copyWith(soundEnabled: v),
                      ),
                    ),

                    const SizedBox(height: 6),

                    // ── Data ────────────────────────────────────────────────────
                    _sectionLabel('Data'),
                    _tile(
                      icon: Icons.history,
                      iconColor: AppTheme.teal,
                      label: 'Activity Log',
                      subtitle: '${prov.logs.length} activities recorded',
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const ActivityLogScreen())),
                    ),
                    _tile(
                      icon: Icons.download,
                      iconColor: AppTheme.lavender,
                      label: 'Export Local Data',
                      subtitle: 'Backup all local data',
                      onTap: _exportData,
                    ),
                    _tile(
                      icon: Icons.delete_sweep,
                      iconColor: Colors.redAccent,
                      label: 'Clear Local Data',
                      subtitle: 'Delete all local data (cloud data stays safe)',
                      onTap: _confirmClearLocal,
                    ),

                    const SizedBox(height: 6),

                    // ── About ────────────────────────────────────────────────────
                    _sectionLabel('About'),
                    _tile(
                      icon: Icons.info_outline,
                      iconColor: AppTheme.softBrown,
                      label: 'About PersiPal',
                      onTap: _showAbout,
                    ),
                    _tile(
                      icon: Icons.help_outline,
                      iconColor: AppTheme.softBrown,
                      label: 'How to Use',
                      onTap: _showHelp,
                    ),

                    const SizedBox(height: 30),

                    // Footer
                    const Center(
                      child: Column(
                        children: [
                          Icon(Icons.pets, color: AppTheme.salmon, size: 28),
                          SizedBox(height: 4),
                          Text('PERSIPAL  v1.0.0',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.softBrown,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1)),
                          SizedBox(height: 4),
                          Text('© 2025 PersiPal Team',
                              style:
                                  TextStyle(fontSize: 10, color: Colors.grey)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Widget helpers ─────────────────────────────────────────────────────────

  Widget _sectionLabel(String label) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
        child: Text(label.toUpperCase(),
            style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
                color: AppTheme.softBrown)),
      );

  Widget _accountTile(User? user) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.82),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppTheme.salmon.withOpacity(0.15),
            backgroundImage:
                user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
            child: user?.photoURL == null
                ? Text(
                    (user?.displayName ?? user?.email ?? 'U')
                        .substring(0, 1)
                        .toUpperCase(),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: AppTheme.salmon))
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.displayName ?? 'Cat Parent',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14),
                ),
                Text(
                  user?.email ?? '',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.teal.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text('Signed in',
                style: TextStyle(
                    fontSize: 10,
                    color: AppTheme.teal,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _tile({
    required IconData icon,
    required Color iconColor,
    required String label,
    String? subtitle,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.82),
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListTile(
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: iconColor),
        ),
        title: Text(label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        subtitle: subtitle != null
            ? Text(subtitle,
                style: const TextStyle(fontSize: 11, color: Colors.grey))
            : null,
        trailing: trailing ??
            (onTap != null
                ? const Icon(Icons.arrow_forward_ios,
                    size: 14, color: Colors.grey)
                : null),
        onTap: onTap,
      ),
    );
  }

  Widget _switchTile({
    required IconData icon,
    required Color iconColor,
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.82),
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListTile(
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: iconColor),
        ),
        title: Text(label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        trailing: Switch.adaptive(
          value: value,
          onChanged: onChanged,
          activeColor: AppTheme.salmon,
        ),
      ),
    );
  }

  // ── Dialogs ────────────────────────────────────────────────────────────────

  Widget _confirmDialog(
    BuildContext ctx, {
    required String title,
    required String body,
    required String confirmLabel,
    required Color confirmColor,
  }) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: AppTheme.creamLight,
      title: Row(children: [
        const Icon(Icons.warning_amber_rounded, color: Colors.orange),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ]),
      content: Text(body, style: const TextStyle(fontSize: 13)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: confirmColor,
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    );
  }

  void _showAbout() => showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: AppTheme.creamLight,
          title: const Row(children: [
            Icon(Icons.pets, color: AppTheme.salmon),
            SizedBox(width: 8),
            Text('About PersiPal',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ]),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('PersiPal',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              SizedBox(height: 4),
              Text('Version 1.0.0',
                  style: TextStyle(fontSize: 13, color: Colors.grey)),
              SizedBox(height: 10),
              Text(
                'An Interactive Mobile Application for Persian Cat Care. '
                'Learn, simulate, and manage your Persian cat\'s health and happiness.',
                style: TextStyle(fontSize: 13),
              ),
              SizedBox(height: 10),
              Text('© 2025 PersiPal Team',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        ),
      );

  void _showHelp() => showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: AppTheme.creamLight,
          title: const Row(children: [
            Icon(Icons.help_outline, color: AppTheme.salmon),
            SizedBox(width: 8),
            Text('How to Use', style: TextStyle(fontWeight: FontWeight.bold)),
          ]),
          content: const SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HelpItem(
                    icon: Icons.pets,
                    title: 'Virtual Cat Simulation',
                    desc:
                        'Feed, groom, and play with your virtual Persian cat.'),
                _HelpItem(
                    icon: Icons.menu_book,
                    title: 'Educational Lessons',
                    desc:
                        'Browse lessons on cat care, nutrition, and grooming.'),
                _HelpItem(
                    icon: Icons.alarm,
                    title: 'Care Reminders',
                    desc: 'Set feeding, grooming, and vet visit reminders.'),
                _HelpItem(
                    icon: Icons.account_circle,
                    title: 'Pet Profile',
                    desc: 'Add and manage your Persian cat\'s profile.'),
                _HelpItem(
                    icon: Icons.quiz,
                    title: 'Quiz',
                    desc: 'Test your Persian cat care knowledge.'),
                _HelpItem(
                    icon: Icons.cloud_sync,
                    title: 'Cloud Sync',
                    desc: 'Sign in to sync your data across devices.'),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Got it!'),
            ),
          ],
        ),
      );

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _HelpItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;

  const _HelpItem(
      {required this.icon, required this.title, required this.desc});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppTheme.salmon),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13)),
                Text(desc,
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
