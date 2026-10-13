/// The version of this build. `main.dart` holds the build-time values (the
/// build script stamps them there) and hands them over once at start.
abstract final class AppVersion {
  const AppVersion._();

  static const String unknown = 'unknown';

  /// `unknown` until [initialize] ran, e.g. in tests.
  static String version = unknown;

  /// The full build name, e.g. `0.17.0+git20261013160833.ba2e5787f662`.
  static String build = unknown;

  static void initialize({required String version, required String build}) {
    AppVersion.version = version;
    AppVersion.build = build;
  }

  /// The day this build was made, as `2026-10-13`, or empty when the build
  /// name carries none.
  static String get buildDate => dateOf(build);

  /// The date in a build name like `0.17.0+git20261013160833.ba2e5787f662`:
  /// the first eight digits after `git`. The commit hash is not shown.
  static String dateOf(String build) {
    final match = _gitDate.firstMatch(build);
    if (match == null) {
      return '';
    }
    return '${match[1]}-${match[2]}-${match[3]}';
  }

  static final RegExp _gitDate = RegExp(r'\+git(\d{4})(\d{2})(\d{2})');
}
