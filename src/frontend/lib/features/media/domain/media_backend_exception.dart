/// Kind of failure a [MediaBackendException] represents, coarse enough for
/// the UI to decide what to show without inspecting gRPC status codes.
enum MediaErrorKind {
  /// The backend is unreachable or the call timed out - triggers the
  /// connection-lost banner and the reconnect loop.
  offline,

  /// The requested resource (playlist, media item) does not exist.
  notFound,

  /// A create call collided with an existing resource (e.g. playlist name).
  alreadyExists,

  /// The request itself was invalid (e.g. an empty playlist name).
  invalidInput,

  /// The backend refused the command given its current state (e.g. `Next`
  /// at the end of the queue). Expected during normal use, not a failure.
  precondition,

  /// Anything else.
  unknown,
}

/// UI-facing failure raised by [MediaRepository] implementations.
///
/// Controllers only ever see this type - raw `GrpcError`s and transport
/// failures are converted at the data layer boundary.
class MediaBackendException implements Exception {
  const MediaBackendException(this.kind, this.message);

  final MediaErrorKind kind;
  final String message;

  @override
  String toString() => 'MediaBackendException($kind, $message)';
}
