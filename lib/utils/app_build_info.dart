/// Build-time metadata about which git commit produced this binary.
///
/// Populated via `--dart-define` from the Makefile. The values are
/// `const` so they get baked into the AOT-compiled output and are
/// available without a `Future`. When the binary is produced outside
/// the Makefile (a bare `flutter run` on a dev machine, or a Dart
/// `dart run` of the CLI), both fields fall back to `'dev'` rather
/// than blowing up.
///
/// The full SHA is what we send to Sentry as a tag so we can correlate
/// crashes to the exact source tree, even after the SemVer build
/// number rolls. The short SHA is what the About page displays — full
/// SHAs are unreadable, and the About page links the user to the
/// commit on GitHub anyway.
class AppBuildInfo {
  /// Full 40-character git commit SHA, or `'dev'` if the build was
  /// produced without `--dart-define=GIT_COMMIT=...` set (e.g. a
  /// developer `flutter run`).
  static const String commit = String.fromEnvironment(
    'GIT_COMMIT',
    defaultValue: 'dev',
  );

  /// Abbreviated commit SHA (typically 7 characters) suitable for
  /// display in the UI. Defaults to `'dev'` when unset, matching
  /// [commit].
  static const String commitShort = String.fromEnvironment(
    'GIT_COMMIT_SHORT',
    defaultValue: 'dev',
  );

  /// Whether this build was produced from a real git commit. Returns
  /// `false` for unset values so callers can hide the GitHub link
  /// (there is nothing to link to) and skip the Sentry tag on a dev
  /// build where the commit field would be useless noise.
  static bool get hasCommit => commit != 'dev' && commit.isNotEmpty;

  /// GitHub URL of the commit, suitable for `url_launcher`. Returns
  /// `null` when [hasCommit] is `false`.
  static String? get commitUrl =>
      hasCommit ? 'https://github.com/DISCOOS/ringdrill/commit/$commit' : null;
}
