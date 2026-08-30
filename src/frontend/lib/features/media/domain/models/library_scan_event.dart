/// Kind of `LibraryEvent.event` string emitted by the backend rescan and
/// library event streams.
enum LibraryScanEventKind {
  scanStarted,
  progress,
  error,
  scanCompleted,
  unknown,
}

/// Maps the backend's `LibraryEvent.event` string onto [LibraryScanEventKind].
LibraryScanEventKind libraryScanEventKindFrom(String raw) {
  return switch (raw.trim()) {
    'scan_started' => LibraryScanEventKind.scanStarted,
    'progress' => LibraryScanEventKind.progress,
    'error' => LibraryScanEventKind.error,
    'scan_completed' => LibraryScanEventKind.scanCompleted,
    _ => LibraryScanEventKind.unknown,
  };
}

/// One update from a `MediaService.RescanMedia` or `StreamLibraryEvents` call.
class LibraryScanEvent {
  const LibraryScanEvent({
    required this.kind,
    required this.scanId,
    required this.processed,
    required this.imported,
    required this.path,
    required this.message,
  });

  final LibraryScanEventKind kind;
  final int scanId;
  final int processed;
  final int imported;
  final String path;
  final String message;
}
