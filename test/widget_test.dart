import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:persipal_app/firebase_options.dart';
import 'package:persipal_app/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Install the Firebase Core mock before any app/service reads Firebase.
    setupFirebaseCoreMocks();

    // Some versions of the Firebase test platform can report an empty
    // Firebase.apps list even though the default app has already been
    // registered internally. Treat only that specific duplicate-app error
    // as harmless; rethrow all other initialization failures.
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } on FirebaseException catch (error) {
      if (error.code != 'duplicate-app') rethrow;
    }
  });

  testWidgets('Persipal app loads', (WidgetTester tester) async {
    await tester.pumpWidget(const PersipalApp());

    // Allow the 2.8-second splash timer and its exit animation to finish.
    await tester.pump(const Duration(milliseconds: 3000));
    await tester.pump(const Duration(milliseconds: 1000));

    expect(find.byType(PersipalApp), findsOneWidget);
  });
}
