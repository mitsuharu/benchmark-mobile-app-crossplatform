import 'dart:async';

import 'github_client.dart';

/// One repository as the search screen reports it to the home screen.
class SearchedRepository {
  const SearchedRepository({
    required this.id,
    required this.fullName,
    required this.stars,
    required this.language,
  });

  factory SearchedRepository.of(Repository repository) => SearchedRepository(
    id: repository.id,
    fullName: repository.fullName,
    stars: repository.stars,
    language: repository.language,
  );

  final int id;
  final String fullName;
  final int stars;
  final String? language;

  @override
  bool operator ==(Object other) =>
      other is SearchedRepository &&
      other.id == id &&
      other.fullName == fullName &&
      other.stars == stars &&
      other.language == language;

  @override
  int get hashCode => Object.hash(id, fullName, stars, language);
}

/// What the search screen reports back.
sealed class RepoSearchEvent {
  const RepoSearchEvent();
}

class SearchSucceeded extends RepoSearchEvent {
  const SearchSucceeded(this.keyword, this.repositories);

  final String keyword;
  final List<SearchedRepository> repositories;
}

class SearchFailed extends RepoSearchEvent {
  const SearchFailed(this.keyword, this.message);

  final String keyword;
  final String message;
}

/// What is asked of the search screen while it is open. The mirror image of
/// [RepoSearchEvent].
sealed class RepoSearchCommand {
  const RepoSearchCommand();
}

/// Replaces the keyword on a screen that is already open. The keyword given to
/// the screen only reaches it while it is being created.
class SetKeyword extends RepoSearchCommand {
  const SetKeyword(this.keyword);

  final String keyword;
}

/// The message bus between the two screens.
///
/// Every implementation carries the same two kinds of traffic — results out of
/// the search screen, commands into it — so the measurements line up. Here
/// both ends are Dart, and nothing crosses into the native side.
class AppChannel {
  AppChannel();

  static final AppChannel shared = AppChannel();

  final _events = StreamController<RepoSearchEvent>.broadcast(sync: true);
  final _commands = StreamController<RepoSearchCommand>.broadcast(sync: true);

  Stream<RepoSearchEvent> get events => _events.stream;

  Stream<RepoSearchCommand> get commands => _commands.stream;

  void post(RepoSearchEvent event) => _events.add(event);

  void send(RepoSearchCommand command) => _commands.add(command);

  void dispose() {
    _events.close();
    _commands.close();
  }
}
