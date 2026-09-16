import 'package:flutter_test/flutter_test.dart';
import 'package:flutterapp/src/app_channel.dart';

import 'fakes.dart';

void main() {
  late AppChannel channel;

  setUp(() => channel = AppChannel());
  tearDown(() => channel.dispose());

  test('delivers events to every listener', () {
    final first = <RepoSearchEvent>[];
    final second = <RepoSearchEvent>[];
    channel.events.listen(first.add);
    channel.events.listen(second.add);

    channel.post(
      SearchSucceeded('expo', [SearchedRepository.of(expoRepository)]),
    );

    expect(first, hasLength(1));
    expect(second, hasLength(1));
    final event = first.single as SearchSucceeded;
    expect(event.keyword, 'expo');
    expect(event.repositories.single.fullName, 'expo/expo');
  });

  test('sends commands to the screen', () {
    final commands = <RepoSearchCommand>[];
    channel.commands.listen(commands.add);

    channel.send(const SetKeyword('swift'));

    expect((commands.single as SetKeyword).keyword, 'swift');
  });

  test('events and commands travel separately', () {
    final events = <RepoSearchEvent>[];
    final commands = <RepoSearchCommand>[];
    channel.events.listen(events.add);
    channel.commands.listen(commands.add);

    channel.send(const SetKeyword('swift'));

    expect(events, isEmpty);
    expect(commands, hasLength(1));
  });

  test('sending with no screen open is harmless', () {
    channel.send(const SetKeyword('swift'));
  });

  test('keeps only the fields the home screen consumes', () {
    final repository = SearchedRepository.of(bareRepository);

    expect(repository.id, 1);
    expect(repository.fullName, 'a/b');
    expect(repository.stars, 0);
    expect(repository.language, isNull);
  });
}
