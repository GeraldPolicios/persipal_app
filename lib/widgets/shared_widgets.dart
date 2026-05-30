// lib/widgets/shared_widgets.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/firebase_sync_service.dart'
    show SyncState; // FIX: only import the enum, not AppProvider
import '../themes/app_theme.dart';

// ── BounceButton ──────────────────────────────────────────────────────────────

class BounceButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final double scale;

  const BounceButton({
    super.key,
    required this.child,
    required this.onTap,
    this.scale = 0.94,
  });

  @override
  State<BounceButton> createState() => _BounceButtonState();
}

class _BounceButtonState extends State<BounceButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 100));
    _anim = Tween<double>(begin: 1.0, end: widget.scale)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: AnimatedBuilder(
        animation: _anim,
        builder: (_, child) =>
            Transform.scale(scale: _anim.value, child: child),
        child: widget.child,
      ),
    );
  }
}

// ── StatBar ───────────────────────────────────────────────────────────────────

class StatBar extends StatelessWidget {
  final String emoji;
  final String label;
  final int value;
  final Color color;
  final bool isLast;

  const StatBar({
    super.key,
    required this.emoji,
    required this.label,
    required this.value,
    required this.color,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          SizedBox(
            width: 76,
            child: Text(label,
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: value / 100,
                minHeight: 8,
                backgroundColor: color.withOpacity(0.15),
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 36,
            child: Text('$value%',
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.bold, color: color)),
          ),
        ],
      ),
    );
  }
}

// ── SyncStatusBadge ───────────────────────────────────────────────────────────

class SyncStatusBadge extends StatelessWidget {
  const SyncStatusBadge({super.key});

  @override
  Widget build(BuildContext context) {
    // FIX: explicitly typed as AppProvider — no more Object? ambiguity
    return Consumer<AppProvider>(
      builder: (_, AppProvider prov, __) {
        final state = prov.syncState;
        if (state == SyncState.idle) return const SizedBox.shrink();

        IconData icon;
        Color color;
        String label;

        switch (state) {
          case SyncState.syncing:
            icon = Icons.sync;
            color = AppTheme.teal;
            label = 'Syncing…';
            break;
          case SyncState.synced:
            icon = Icons.cloud_done;
            color = Colors.green;
            label = 'Synced';
            break;
          case SyncState.failed:
            icon = Icons.cloud_off;
            color = Colors.redAccent;
            label = 'Sync failed';
            break;
          case SyncState.offline:
            icon = Icons.wifi_off;
            color = AppTheme.softBrown;
            label = 'Offline';
            break;
          default:
            return const SizedBox.shrink();
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              state == SyncState.syncing
                  ? SizedBox(
                      width: 10,
                      height: 10,
                      child: CircularProgressIndicator(
                          strokeWidth: 1.5, color: color),
                    )
                  : Icon(icon, size: 12, color: color),
              const SizedBox(width: 4),
              Text(label,
                  style: TextStyle(
                      fontSize: 10, color: color, fontWeight: FontWeight.w600)),
            ],
          ),
        );
      },
    );
  }
}

// ── LoadingOverlay ────────────────────────────────────────────────────────────

class LoadingOverlay extends StatelessWidget {
  final String? message;

  const LoadingOverlay({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black38,
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.creamLight,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppTheme.salmon),
              if (message != null) ...[
                const SizedBox(height: 12),
                Text(message!,
                    style: const TextStyle(
                        fontSize: 13, color: AppTheme.softBrown)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── EmptyState ────────────────────────────────────────────────────────────────

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Opacity(
              opacity: 0.35,
              child: Icon(icon, size: 80, color: AppTheme.salmon),
            ),
            const SizedBox(height: 16),
            Text(title,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.softBrown)),
            const SizedBox(height: 8),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Colors.grey)),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── PawBackground ─────────────────────────────────────────────────────────────

class PawBackground extends StatelessWidget {
  final double opacity;

  const PawBackground({super.key, this.opacity = 0.12});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Opacity(
        opacity: opacity,
        child: Image.asset('assets/images/paws_bg.png', fit: BoxFit.cover),
      ),
    );
  }
}

// ── PersipalSnackBar ─────────────────────────────────────────────────────────

void showPersipalSnackBar(
  BuildContext context,
  String message, {
  Color? color,
  IconData? icon,
  bool isError = false,
}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
          ],
          Expanded(child: Text(message)),
        ],
      ),
      backgroundColor: color ?? (isError ? Colors.redAccent : AppTheme.teal),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}
