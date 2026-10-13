/// Why a password call did not go through.
enum ExitPasswordFailure {
  /// The backend did not answer.
  unreachable,

  /// The current password was wrong (`PERMISSION_DENIED`).
  wrongCurrent,

  /// The new password breaks the rules (`INVALID_ARGUMENT`).
  rejected,

  /// The backend could not save it (`INTERNAL`) or answered something else.
  failed,
}

class ExitPasswordException implements Exception {
  const ExitPasswordException(this.failure, [this.detail = '']);

  final ExitPasswordFailure failure;

  /// What the backend said, for the log only - never shown to the user.
  final String detail;

  @override
  String toString() => 'ExitPasswordException(${failure.name}): $detail';
}

/// The rules for a new password, as the backend states them: 4 to 64
/// characters, no control characters. The backend decides; the interface
/// checks them first so a typo does not cost a round trip.
abstract final class ExitPasswordRules {
  const ExitPasswordRules._();

  static const int minLength = 4;
  static const int maxLength = 64;

  static bool isValid(String password) {
    final length = password.runes.length;
    if (length < minLength || length > maxLength) {
      return false;
    }
    return password.runes.every((rune) => !_isControl(rune));
  }

  static bool _isControl(int rune) =>
      rune < 0x20 || (rune >= 0x7f && rune <= 0x9f);
}

/// Where the password for "Beenden" is checked and changed. The backend keeps
/// it as a hash (`SystemService`); the frontend never stores it (#51).
abstract interface class ExitPasswordStore {
  /// `false` for a wrong password - that is an answer, not an error. Throws
  /// an [ExitPasswordException] when the backend cannot be asked.
  Future<bool> verify(String password);

  /// Sets a new password. The current one has to be given again. Throws an
  /// [ExitPasswordException] with the reason when it does not work.
  Future<void> change({required String current, required String next});
}
