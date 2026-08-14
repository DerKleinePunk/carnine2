/// Immutable track metadata shown by the media player and its queue.
class MediaTrack {
  const MediaTrack({
    required this.title,
    required this.artist,
    required this.album,
    required this.releaseYear,
    required this.duration,
  });

  final String title;
  final String artist;
  final String album;
  final int releaseYear;
  final Duration duration;
}
