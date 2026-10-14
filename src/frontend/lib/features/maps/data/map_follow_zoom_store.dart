/// Where the zoom of following the car is kept (#131): `UiState.map_follow_zoom`
/// in the backend. The frontend stores nothing itself.
abstract interface class MapFollowZoomStore {
  /// The saved zoom level, or 0 when none was ever saved (then the default
  /// applies).
  Future<int> loadFollowZoom();

  /// Saves [zoom]. The backend refuses a level above 22.
  Future<void> saveFollowZoom(int zoom);
}
