import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutterapp/src/app_channel.dart';
import 'package:flutterapp/src/github_client.dart';
import 'package:flutterapp/src/palette.dart';
import 'package:flutterapp/src/repo_search_screen.dart';

import 'fakes.dart';

void main() {
  late AppChannel channel;
  late FakeBenchMarker marker;

  setUp(() {
    channel = AppChannel();
    marker = FakeBenchMarker();
  });

  tearDown(() => channel.dispose());

  Future<void> pumpScreen(
    WidgetTester tester, {
    String keyword = 'expo',
    GitHubClient? client,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: RepoSearchScreen(
          initialKeyword: keyword,
          client: client ?? FakeGitHubClient(),
          channel: channel,
          marker: marker,
        ),
      ),
    );
  }

  testWidgets('shows the keyword handed over by the home screen', (
    tester,
  ) async {
    await pumpScreen(tester, keyword: 'flutter');

    expect(find.text('keyword: flutter'), findsOneWidget);
  });

  testWidgets('does not search until the button is pressed', (tester) async {
    final client = FakeGitHubClient();
    await pumpScreen(tester, client: client);

    expect(client.keywords, isEmpty);
    expect(find.text('ボタンを押すと検索結果が表示されます。'), findsOneWidget);
  });

  testWidgets('lists the repositories returned for the keyword', (
    tester,
  ) async {
    final client = FakeGitHubClient(results: [expoRepository, bareRepository]);
    await pumpScreen(tester, client: client);

    await tester.tap(find.text('リポジトリを検索'));
    await tester.pumpAndSettle();

    expect(client.keywords, ['expo']);
    expect(find.text('expo/expo'), findsOneWidget);
    expect(find.text('★ 51,842 · TypeScript'), findsOneWidget);
    // A repository with no language shows the star count on its own.
    expect(find.text('★ 0'), findsOneWidget);
  });

  testWidgets('reports the results back to the home screen', (tester) async {
    final events = <RepoSearchEvent>[];
    channel.events.listen(events.add);
    await pumpScreen(
      tester,
      client: FakeGitHubClient(results: [expoRepository]),
    );

    await tester.tap(find.text('リポジトリを検索'));
    await tester.pumpAndSettle();

    final event = events.single as SearchSucceeded;
    expect(event.keyword, 'expo');
    expect(event.repositories, [SearchedRepository.of(expoRepository)]);
  });

  testWidgets('shows the failure and reports it to the home screen', (
    tester,
  ) async {
    final events = <RepoSearchEvent>[];
    channel.events.listen(events.add);
    await pumpScreen(
      tester,
      client: FakeGitHubClient(
        error: const GitHubException('API rate limit exceeded'),
      ),
    );

    await tester.tap(find.text('リポジトリを検索'));
    await tester.pumpAndSettle();

    expect(find.text('API rate limit exceeded'), findsOneWidget);
    final event = events.single as SearchFailed;
    expect((event.keyword, event.message), ('expo', 'API rate limit exceeded'));
  });

  testWidgets('sends a keyword over the channel when a preset is pressed', (
    tester,
  ) async {
    final commands = <RepoSearchCommand>[];
    channel.commands.listen(commands.add);
    await pumpScreen(tester);

    await tester.tap(find.text('swift'));
    await tester.pump();

    expect((commands.single as SetKeyword).keyword, 'swift');
  });

  testWidgets('follows a keyword sent while the screen is open', (
    tester,
  ) async {
    final client = FakeGitHubClient(results: [expoRepository]);
    await pumpScreen(tester, client: client);

    channel.send(const SetKeyword('swift'));
    await tester.pump();
    expect(find.text('keyword: swift'), findsOneWidget);

    await tester.tap(find.text('リポジトリを検索'));
    await tester.pumpAndSettle();
    expect(client.keywords, ['swift']);
  });

  testWidgets('clears the previous results when the keyword is replaced', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      client: FakeGitHubClient(results: [expoRepository]),
    );
    await tester.tap(find.text('リポジトリを検索'));
    await tester.pumpAndSettle();

    channel.send(const SetKeyword('swift'));
    await tester.pumpAndSettle();

    expect(find.text('keyword: swift'), findsOneWidget);
    expect(find.text('expo/expo'), findsNothing);
  });

  testWidgets('marks each step of the benchmark scenario', (tester) async {
    await pumpScreen(
      tester,
      client: FakeGitHubClient(results: [expoRepository]),
    );
    expect(marker.marks, ['searchFirstFrame']);

    await tester.tap(find.text('リポジトリを検索'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('swift'));
    await tester.pump();

    expect(marker.marks, [
      'searchFirstFrame',
      'searchTapped',
      'searchRendered',
      'commandSent',
      'keywordApplied',
    ]);
  });

  test('groups star counts by thousands', () {
    expect(groupThousands(0), '0');
    expect(groupThousands(999), '999');
    expect(groupThousands(51842), '51,842');
    expect(groupThousands(1234567), '1,234,567');
  });
}
