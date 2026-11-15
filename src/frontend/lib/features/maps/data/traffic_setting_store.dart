/// Where the switch for traffic from the internet is kept:
/// `UiState.traffic_enabled` in the backend. The frontend stores nothing
/// itself.
abstract interface class TrafficSettingStore {
  /// Whether traffic is on; `false` while it was never switched.
  Future<bool> loadTrafficEnabled();

  Future<void> saveTrafficEnabled(bool enabled);
}
