import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:persipal_app/services/session_manager.dart';

class _FakeUser extends Fake implements User {}

void main() {
  test('startup waits for Firebase to emit its restored user', () async {
    final authStates = StreamController<User?>();
    final restoredUser = _FakeUser();
    var completed = false;

    final result = waitForInitialAuthState(authStates.stream).then((user) {
      completed = true;
      return user;
    });

    await Future<void>.delayed(Duration.zero);
    expect(completed, isFalse);

    authStates.add(restoredUser);
    expect(await result, same(restoredUser));
    await authStates.close();
  });

  test('startup accepts an initial null event as a guest state', () async {
    final user = await waitForInitialAuthState(Stream<User?>.value(null));

    expect(user, isNull);
  });

  test('startup waits briefly after null when a cached account exists', () async {
    final authStates = StreamController<User?>();
    final restoredUser = _FakeUser();
    final result = waitForInitialAuthState(
      authStates.stream,
      waitAfterInitialNull: true,
      restoreGracePeriod: const Duration(seconds: 1),
    );

    authStates.add(null);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    authStates.add(restoredUser);

    expect(await result, same(restoredUser));
    await authStates.close();
  });

  test('startup stays unauthenticated if cached account does not restore', () async {
    final authStates = StreamController<User?>();
    final result = waitForInitialAuthState(
      authStates.stream,
      waitAfterInitialNull: true,
      restoreGracePeriod: const Duration(milliseconds: 20),
    );

    authStates.add(null);
    expect(await result, isNull);
    await authStates.close();
  });
}
