// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'providers/app_provider.dart';
import 'providers/virtual_pet_provider.dart';
import 'providers/reminder_provider.dart';
import 'providers/pet_profile_provider.dart';
import 'services/activity_log_service.dart';
import 'services/activity_service.dart';
import 'services/lesson_progress_service.dart';
import 'services/reward_service.dart';
import 'services/virtual_sound_service.dart';
import 'services/virtual_achievement_service.dart';
import 'services/pet_photo_service.dart';
import 'services/auth_service.dart';
import 'services/connectivity_service.dart';
import 'services/firebase_sync_service.dart';
import 'services/local_storage_service.dart';
import 'services/session_manager.dart';
import 'services/notification_service.dart';
import 'screens/splash_screen.dart';
import 'screens/reminder_screen.dart';
import 'models/dirty_state.dart';

/// Attached to MaterialApp below. Lets a notification tap open the exact
/// Reminder Screen it points at from anywhere — no matter what screen is
/// currently showing — without NotificationService importing navigation/
/// screen code directly (see NotificationService.onReminderNotificationTap).
final rootNavigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Hive — must initialise before anything reads local data
  await LocalStorageService.instance.init();

  // 2. Firebase — initialise once, never required for startup
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 3. Auth listener
  await AuthService.instance.init();

  // 4. Connectivity watcher
  await ConnectivityService.instance.init();

  // 5. Session manager — restores last session from Hive
  await SessionManager.instance.init();

  // 6. Activity log — loads from Hive
  await ActivityLogService.instance.init();

  // 6b. Activity service — the real, user-facing activity feed
  await ActivityService.instance.init();

  // 6b2. Lesson progress — which Learn Cat Care topics are completed
  await LessonProgressService.instance.init();
  await RewardService.instance.init();

  // 6c. Virtual Cat achievement tracking — loads from Hive
  await VirtualAchievementService.instance.init();

  // 6d. Pet profile photos — loads petId -> local file path map from Hive
  await PetPhotoService.instance.init();

  // 7. Notification service — requests permissions, sets up channels
  await NotificationService.instance.init();

  // 8. Reminder provider — constructed eagerly (rather than lazily inside
  // MultiProvider's create) so the notification-action wiring below is
  // guaranteed to be in place, and any "Mark Done" tap that cold-started
  // the app just now is never silently dropped, before the first frame.
  final reminderProvider = ReminderProvider();
  await reminderProvider.init();

  // Cross-provider wiring via injected callbacks — avoids a circular
  // import between reminder_provider.dart and pet_profile_provider.dart
  // (see each field's doc comment).
  ReminderProvider.petNameResolver =
      (petId) => PetProfileProvider.instance.getById(petId)?.name;
  ReminderProvider.onReminderCompleted =
      PetProfileProvider.instance.checkCareAchievements;
  NotificationService.onMarkDoneAction = reminderProvider.completeReminderOccurrence;
  NotificationService.instance.consumeStartupAction();

  runApp(PersipalApp(reminderProvider: reminderProvider));

  // Wire live notification-tap navigation now that runApp() has scheduled
  // the first frame — rootNavigatorKey only attaches to a mounted Navigator
  // once that frame actually builds, which is why this couldn't be set any
  // earlier (in particular, not before the consumeStartupAction() call
  // above, which may itself synchronously process a cold-start tap).
  WidgetsBinding.instance.addPostFrameCallback((_) {
    NotificationService.onReminderNotificationTap = (reminderId) {
      rootNavigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => ReminderScreen(openReminderId: reminderId),
        ),
      );
    };

    // Flush whatever a plain tap stashed before a live Navigator existed —
    // either the cold-start tap consumeStartupAction() may have just
    // processed above, or one that arrived in the brief window between
    // runApp() and this callback.
    final pendingReminderId =
        NotificationService.instance.consumePendingReminderNavigation();
    if (pendingReminderId != null) {
      NotificationService.onReminderNotificationTap!(pendingReminderId);
    }
  });
}

class PersipalApp extends StatelessWidget {
  // Nullable + defaulted (rather than required) so existing callers that
  // construct PersipalApp without one — e.g. test/widget_test.dart — keep
  // working unchanged, falling back to the original lazily-created,
  // not-notification-wired instance.
  final ReminderProvider? reminderProvider;

  const PersipalApp({super.key, this.reminderProvider});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppProvider()..init()),
        ChangeNotifierProvider(create: (_) {
          final vp = VirtualPetProvider()..init();
          // Forwards the virtual pet's already-persisted feed/groom/play
          // counters to VirtualAchievementService on every change, without
          // VirtualPetProvider (frozen) needing any achievement awareness.
          vp.addListener(() {
            VirtualAchievementService.instance.onVirtualPetChanged(vp.pet);
            // Sound effects + daily-capped reward points for virtual-cat
            // actions — both observe the same public counters, and only
            // once the saved cat has loaded (so start-up isn't an "action").
            if (!vp.loading) {
              VirtualSoundService.instance.onVirtualPetChanged(vp.pet);
              RewardService.instance.onVirtualPetChanged(vp.pet);
              ActivityLogService.instance.onVirtualPetChanged(vp.pet);
            }
          });
          return vp;
        }),
        reminderProvider != null
            ? ChangeNotifierProvider.value(value: reminderProvider!)
            : ChangeNotifierProvider(create: (_) => ReminderProvider()..init()),
        ChangeNotifierProvider.value(value: ActivityLogService.instance),
        ChangeNotifierProvider.value(value: ActivityService.instance),
        ChangeNotifierProvider.value(value: LessonProgressService.instance),
        ChangeNotifierProvider.value(value: RewardService.instance),
        ChangeNotifierProvider.value(value: AuthService.instance),
        ChangeNotifierProvider.value(value: SessionManager.instance),
        ChangeNotifierProvider.value(value: ConnectivityService.instance),
        ChangeNotifierProvider.value(value: FirebaseSyncService.instance),
        ChangeNotifierProvider.value(value: DirtyState.instance),
      ],
      child: MaterialApp(
        navigatorKey: rootNavigatorKey,
        debugShowCheckedModeBanner: false,
        title: 'PERSIPAL',
        theme: ThemeData(
          fontFamily: 'Nunito',
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFFFF8C69),
            brightness: Brightness.light,
          ),
          useMaterial3: true,
        ),
        home: const SplashScreen(),
      ),
    );
  }
}
