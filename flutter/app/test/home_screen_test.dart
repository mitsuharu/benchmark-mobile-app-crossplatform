import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutterapp/src/app_channel.dart';
import 'package:flutterapp/src/home_screen.dart';

import 'fakes.dart';

void main() {
  late AppChannel channel;
  late FakeBenchMarker marker;
  late List<String> baseUrls;

  setUp(() {
    channel = AppChannel();
    marker = FakeBenchMarker();
    baseUrls = [];
  });

  tearDown(() => channel.dispose());

  Future<void> pumpHome(
    WidgetTester tester, {
    FakeGitHubClient? client,
    String apiBaseUrl = 'http://127.0.0.1:8787',
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          channel: channel,
          apiBaseUrl: apiBaseUrl,
          marker: marker,
          createClient: (baseUrl) {
            baseUrls.add(baseUrl);
            return client ?? FakeGitHubClient();
          },
        ),
      ),
    );
  }

  testWidgets('starts with no results', (tester) async {
    await pumpHome(tester);

    expect(find.text('まだ結果を受け取っていません'), findsOneWidget);
  });

  testWidgets('shows what the search screen reports', (tester) async {
    await pumpHome(tester);

    channel.post(
      SearchSucceeded('expo', [SearchedRepository.of(expoRepository)]),
    );
    await tester.pump();

    expect(find.text('keyword: expo'), findsOneWidget);
    expect(find.text('件数: 1'), findsOneWidget);
    expect(find.text('expo/expo'), findsOneWidget);
    expect(marker.marks, contains('resultsReceived'));
  });

  testWidgets('a failure clears previous results', (tester) async {
    await pumpHome(tester);

    channel.post(
      SearchSucceeded('expo', [SearchedRepository.of(expoRepository)]),
    );
    await tester.pump();
    channel.post(const SearchFailed('expo', 'API rate limit exceeded'));
    await tester.pump();

    expect(find.text('API rate limit exceeded'), findsOneWidget);
    expect(find.text('expo/expo'), findsNothing);
  });

  testWidgets('opens the search screen with the typed keyword', (tester) async {
    final client = FakeGitHubClient();
    await pumpHome(tester, client: client);

    await tester.enterText(find.byType(TextField), '  swift-format ');
    await tester.tap(find.text('検索画面を開く'));
    await tester.pumpAndSettle();

    expect(find.text('keyword: swift-format'), findsOneWidget);
    expect(baseUrls, ['http://127.0.0.1:8787']);
    expect(marker.marks, contains('searchOpenTapped'));
  });

  testWidgets('falls back to the default keyword when the field is blank', (
    tester,
  ) async {
    await pumpHome(tester);

    await tester.enterText(find.byType(TextField), '   ');
    await tester.tap(find.text('検索画面を開く'));
    await tester.pumpAndSettle();

    expect(find.text('keyword: $defaultKeyword'), findsOneWidget);
  });

  testWidgets('marks the launch after the first frame', (tester) async {
    await pumpHome(tester);

    expect(marker.marks, ['homeFirstFrame']);
  });
}
