import 'package:carnine_frontend/lib/carnine.pb.dart';

/// Kind of `LibraryEvent.event` emitted by the backend rescan and
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
  playlistCreated,
  playlistEntryAdded,
  unknown,
}

/// Maps the protobuf enum onto the presentation-layer event kind.
LibraryScanEventKind libraryScanEventKindFrom(LibraryEventType raw) {
  return switch (raw) {
    LibraryEventType.LIBRARY_SCAN_STARTED => LibraryScanEventKind.scanStarted,
    LibraryEventType.LIBRARY_PROGRESS => LibraryScanEventKind.progress,
    LibraryEventType.LIBRARY_ERROR => LibraryScanEventKind.error,
    LibraryEventType.LIBRARY_SCAN_COMPLETED =>
      LibraryScanEventKind.scanCompleted,
    LibraryEventType.LIBRARY_MUSIC_FOUND => LibraryScanEventKind.musicFound,
    LibraryEventType.LIBRARY_IMPORT_STARTED =>
      LibraryScanEventKind.importStarted,
    LibraryEventType.LIBRARY_IMPORT_PROGRESS =>
      LibraryScanEventKind.importProgress,
    LibraryEventType.LIBRARY_IMPORT_COMPLETED =>
      LibraryScanEventKind.importCompleted,
    LibraryEventType.PLAYLIST_CREATED => LibraryScanEventKind.playlistCreated,
    LibraryEventType.PLAYLIST_ENTRY_ADDED =>
      LibraryScanEventKind.playlistEntryAdded,
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
    this.playlistId = 0,
    this.playlistName = '',
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
  final int playlistId;
  final String playlistName;
}
