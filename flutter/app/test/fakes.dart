import 'package:flutter/services.dart';
import 'package:flutterapp/src/bench_marker.dart';
import 'package:flutterapp/src/github_client.dart';

const expoRepository = Repository(
  id: 65750241,
  fullName: 'expo/expo',
  description: 'An open-source framework',
  stars: 51842,
  language: 'TypeScript',
  htmlUrl: 'https://github.com/expo/expo',
);

const bareRepository = Repository(
  id: 1,
  fullName: 'a/b',
  description: null,
  stars: 0,
  language: null,
  htmlUrl: 'https://github.com/a/b',
);

/// Answers searches from memory and remembers what was asked.
class FakeGitHubClient extends GitHubClient {
  FakeGitHubClient({this.results = const [], this.error});

  final List<Repository> results;
  final Object? error;
  final keywords = <String>[];

  @override
  Future<List<Repository>> searchRepositories(
    String keyword, {
    int perPage = 20,
  }) async {
    keywords.add(keyword);
    if (error != null) throw error!;
    return results;
  }
}

/// Records the markers instead of reaching for the platform channel.
class FakeBenchMarker extends BenchMarker {
  FakeBenchMarker() : super(channel: const MethodChannel('bench/fake'));

  final marks = <String>[];

  @override
  void mark(String name, {DateTime? at}) => marks.add(name);

  @override
  void markAfterFrame(String name, {bool launch = false}) => marks.add(name);
}
