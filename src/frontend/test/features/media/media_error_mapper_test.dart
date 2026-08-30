import 'package:carnine_frontend/features/media/data/media_error_mapper.dart';
import 'package:carnine_frontend/features/media/domain/media_backend_exception.dart';
import 'package:grpc/grpc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('mediaExceptionFrom', () {
    test('unavailable maps to offline - the transport is actually down', () {
      final error = mediaExceptionFrom(const GrpcError.unavailable('down'));
      expect(error.kind, MediaErrorKind.offline);
    });

    test(
        'deadlineExceeded maps to unknown, not offline - a single slow call '
        'does not mean the connection is lost (e.g. Stop waiting for '
        'external audio processes to exit under WSL)', () {
      final error =
          mediaExceptionFrom(const GrpcError.deadlineExceeded('slow'));
      expect(error.kind, MediaErrorKind.unknown);
    });

    test(
        'notFound/alreadyExists/invalidArgument/failedPrecondition map distinctly',
        () {
      expect(
        mediaExceptionFrom(const GrpcError.notFound('x')).kind,
        MediaErrorKind.notFound,
      );
      expect(
        mediaExceptionFrom(const GrpcError.alreadyExists('x')).kind,
        MediaErrorKind.alreadyExists,
      );
      expect(
        mediaExceptionFrom(const GrpcError.invalidArgument('x')).kind,
        MediaErrorKind.invalidInput,
      );
      expect(
        mediaExceptionFrom(const GrpcError.failedPrecondition('x')).kind,
        MediaErrorKind.precondition,
      );
    });

    test('a non-GrpcError (e.g. a socket failure) maps to offline', () {
      final error = mediaExceptionFrom(Exception('socket closed'));
      expect(error.kind, MediaErrorKind.offline);
    });
  });
}
