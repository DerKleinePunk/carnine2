/// Kind of `LibraryEvent.event` string emitted by the backend rescan and
/// library event streams.
enum LibraryScanEventKind {
  scanStarted,
  progress,
  error,
  scanCompleted,
  musicFound,
  importStarted,
  importProgress,
  importCompleted,
  unknown,
}

/// Maps the backend's `LibraryEvent.event` string onto [LibraryScanEventKind].
LibraryScanEventKind libraryScanEventKindFrom(String raw) {
  return switch (raw.trim()) {
    'scan_started' => LibraryScanEventKind.scanStarted,
    'progress' => LibraryScanEventKind.progress,
    'error' => LibraryScanEventKind.error,
    'scan_completed' => LibraryScanEventKind.scanCompleted,
    'music_found' => LibraryScanEventKind.musicFound,
    'import_started' => LibraryScanEventKind.importStarted,
    'import_progress' => LibraryScanEventKind.importProgress,
    'import_completed' => LibraryScanEventKind.importCompleted,
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
    this.sourceLabel = '',
    this.sourcePath = '',
    this.matchingFiles = 0,
  });

  final LibraryScanEventKind kind;
  final int scanId;
  final int processed;
  final int imported;
  final String path;
  final String message;
  final String sourceLabel;
  final String sourcePath;
  final int matchingFiles;
}
