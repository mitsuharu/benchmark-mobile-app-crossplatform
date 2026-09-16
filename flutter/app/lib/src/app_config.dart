/// Build-time settings.
class AppConfig {
  const AppConfig._();

  static const defaultApiBaseUrl = 'https://api.github.com';

  /// Where the search screen sends its requests. The benchmark build points
  /// this at bench/mock-server with
  /// `--dart-define=BENCH_API_BASE_URL=http://127.0.0.1:8787`; every other
  /// build talks to GitHub.
  static const apiBaseUrl = String.fromEnvironment(
    'BENCH_API_BASE_URL',
    defaultValue: defaultApiBaseUrl,
  );
}
