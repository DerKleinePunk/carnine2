import 'dart:async';

import 'package:carnine_frontend/features/settings/data/exit_password_store.dart';

/// Hand-written [ExitPasswordStore] for tests: the backend with one password
/// in memory. [verifies] and [changes] record every call; [changes] reads
/// `current>next`.
class FakeExitPasswordStore implements ExitPasswordStore {
  FakeExitPasswordStore({this.password = '4321'});

  /// The password the "backend" holds now.
  String password;

  /// Thrown by [verify] while set, to play a backend that is away.
  Object? verifyError;

  /// Thrown by [change], once; cleared after it fired.
  Object? changeError;

  /// Holds [verify] until completed.
  Completer<void>? gate;

  final List<String> verifies = [];
  final List<String> changes = [];

  @override
  Future<bool> verify(String candidate) async {
    verifies.add(candidate);
    await gate?.future;
    final failure = verifyError;
    if (failure != null) {
      throw failure;
    }
    return candidate == password;
  }

  @override
  Future<void> change({required String current, required String next}) async {
    changes.add('$current>$next');
    final failure = changeError;
    if (failure != null) {
      changeError = null;
      throw failure;
    }
    if (current != password) {
      throw const ExitPasswordException(ExitPasswordFailure.wrongCurrent);
    }
    if (!ExitPasswordRules.isValid(next)) {
      throw const ExitPasswordException(ExitPasswordFailure.rejected);
    }
    password = next;
  }
}

const ExitPasswordException backendAway = ExitPasswordException(
  ExitPasswordFailure.unreachable,
  'connection refused',
);
