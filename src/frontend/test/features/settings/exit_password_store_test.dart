import 'dart:io';

import 'package:carnine_frontend/core/app_version.dart';
import 'package:carnine_frontend/data/services/carnine_grpc_service.dart';
import 'package:carnine_frontend/features/settings/data/exit_password_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grpc/grpc.dart';

void main() {
  group('rules for a new password (4 to 64 characters, no control '
      'characters)', () {
    test('4 and 64 characters are fine, 3 and 65 are not', () {
      expect(ExitPasswordRules.isValid('abc'), isFalse);
      expect(ExitPasswordRules.isValid('abcd'), isTrue);
      expect(ExitPasswordRules.isValid('a' * 64), isTrue);
      expect(ExitPasswordRules.isValid('a' * 65), isFalse);
      expect(ExitPasswordRules.isValid(''), isFalse);
    });

    test('umlauts and symbols count as one character each', () {
      expect(ExitPasswordRules.isValid('äöüß'), isTrue);
      expect(ExitPasswordRules.isValid('😀' * 4), isTrue);
      expect(ExitPasswordRules.isValid('😀' * 65), isFalse);
      expect(ExitPasswordRules.isValid('pass wort!'), isTrue);
    });

    test('control characters are refused', () {
      expect(ExitPasswordRules.isValid('ab\ncd'), isFalse);
      expect(ExitPasswordRules.isValid('ab\tcd'), isFalse);
      expect(ExitPasswordRules.isValid('ab\u007fcd'), isFalse);
      expect(ExitPasswordRules.isValid('ab\u0085cd'), isFalse);
    });
  });

  group('what a failed call means', () {
    ExitPasswordFailure failureOf(Object error) =>
        CarnineGrpcService.exitPasswordExceptionFrom(error).failure;

    test('permission denied is the wrong current password', () {
      expect(
        failureOf(GrpcError.permissionDenied('wrong password')),
        ExitPasswordFailure.wrongCurrent,
      );
    });

    test('invalid argument is a password that breaks the rules', () {
      expect(
        failureOf(GrpcError.invalidArgument('too short')),
        ExitPasswordFailure.rejected,
      );
    });

    test('no answer from the backend is "unreachable"', () {
      expect(
        failureOf(GrpcError.unavailable('connection refused')),
        ExitPasswordFailure.unreachable,
      );
      expect(
        failureOf(GrpcError.deadlineExceeded('too slow')),
        ExitPasswordFailure.unreachable,
      );
      expect(
        failureOf(const SocketException('no such socket')),
        ExitPasswordFailure.unreachable,
      );
    });

    test('anything else is "failed"; the message is kept for the log', () {
      final exception = CarnineGrpcService.exitPasswordExceptionFrom(
        GrpcError.internal('could not write the file'),
      );

      expect(exception.failure, ExitPasswordFailure.failed);
      expect(exception.detail, 'could not write the file');
    });
  });

  group('version shown on the System page', () {
    test('the date is the day in the build name, the commit is left out', () {
      expect(
        AppVersion.dateOf('0.17.0+git20261013160833.ba2e5787f662'),
        '2026-10-13',
      );
    });

    test('a build name without a date has none', () {
      expect(AppVersion.dateOf('0.17.0'), isEmpty);
      expect(AppVersion.dateOf('unknown'), isEmpty);
      expect(AppVersion.dateOf('dev-1'), isEmpty);
      expect(AppVersion.dateOf(''), isEmpty);
    });
  });
}
