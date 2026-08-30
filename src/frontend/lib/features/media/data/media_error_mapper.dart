import 'package:carnine_frontend/features/media/domain/media_backend_exception.dart';
import 'package:grpc/grpc.dart';

/// Maps any error thrown by a [MediaRepository] call to a
/// [MediaBackendException], so controllers never see a raw `GrpcError` or
/// transport failure.
MediaBackendException mediaExceptionFrom(Object error) {
  if (error is GrpcError) {
    final message = error.message ?? error.toString();
    return switch (error.code) {
      // Unavailable means the transport itself is down - a real
      // connection-loss signal. deadlineExceeded only means this one call
      // was slower than its client-side timeout (e.g. the backend's Stop
      // waits for external audio processes to exit, which can occasionally
      // take a moment under WSL) - the connection may well be fine, so this
      // must not be treated the same as being offline.
      StatusCode.unavailable =>
        MediaBackendException(MediaErrorKind.offline, message),
      StatusCode.deadlineExceeded =>
        MediaBackendException(MediaErrorKind.unknown, message),
      StatusCode.notFound =>
        MediaBackendException(MediaErrorKind.notFound, message),
      StatusCode.alreadyExists =>
        MediaBackendException(MediaErrorKind.alreadyExists, message),
      StatusCode.invalidArgument =>
        MediaBackendException(MediaErrorKind.invalidInput, message),
      StatusCode.failedPrecondition =>
        MediaBackendException(MediaErrorKind.precondition, message),
      _ => MediaBackendException(MediaErrorKind.unknown, message),
    };
  }

  // Socket errors, timeouts and anything else that isn't a GrpcError means
  // the request never reached (or returned from) the backend at all.
  return MediaBackendException(MediaErrorKind.offline, error.toString());
}
