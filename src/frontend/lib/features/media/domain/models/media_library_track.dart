import 'package:carnine_frontend/features/media/domain/models/media_availability.dart';

/// A single track of the backend media library.
///
/// The protobuf contract carries no album or release year, so neither is
/// modelled here. [duration] is the only source of a track length: the
/// backend's `PlayerState.duration_ms` is always zero.
class MediaLibraryTrack {
  const MediaLibraryTrack({
    required this.id,
    required this.sourceId,
    required this.path,
    required this.title,
    required this.artist,
    required this.duration,
    required this.availability,
  });

  final int id;
  final int sourceId;
  final String path;
  final String title;
  final String artist;
  final Duration duration;
  final MediaAvailability availability;

  bool get isPlayable => availability.isPlayable;

  bool get hasKnownDuration => duration > Duration.zero;

  @override
  bool operator ==(Object other) {
    return other is MediaLibraryTrack && other.id == id && other.path == path;
  }

  @override
  int get hashCode => Object.hash(id, path);
}
