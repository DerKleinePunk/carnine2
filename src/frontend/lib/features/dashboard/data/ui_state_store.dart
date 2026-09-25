/// Keeps what the UI restores after a restart, such as the page shown last.
///
/// The backend stores it next to the playback resume state; tests leave the
/// store out, so they never touch a real backend.
abstract interface class UiStateStore {
  /// Name of the page shown last, or an empty string when none was saved.
  Future<String> loadLastPage();

  Future<void> saveLastPage(String page);
}
