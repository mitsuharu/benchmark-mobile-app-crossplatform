import Foundation

/// One repository as the search screen reports it to the home screen.
struct SearchedRepository: Identifiable, Hashable, Sendable {
  let id: Int
  let fullName: String
  let stars: Int
  let language: String?

  init(id: Int, fullName: String, stars: Int, language: String?) {
    self.id = id
    self.fullName = fullName
    self.stars = stars
    self.language = language
  }

  init(_ repository: Repository) {
    self.init(
      id: repository.id,
      fullName: repository.fullName,
      stars: repository.stars,
      language: repository.language
    )
  }
}

/// What the search screen reports back.
enum RepoSearchEvent {
  case succeeded(keyword: String, repositories: [SearchedRepository])
  case failed(keyword: String, message: String)
}

/// What is asked of the search screen while it is open. The mirror image of
/// `RepoSearchEvent`.
enum RepoSearchCommand: Equatable {
  /// Replaces the keyword on a screen that is already open. The keyword given
  /// to `RepoSearchView` only reaches the screen while it is being created.
  case setKeyword(String)
}

/// The message bus between the two screens.
///
/// Every implementation carries the same two kinds of traffic — results out of
/// the search screen, commands into it — so the measurements line up. Here
/// both ends are Swift in one process, which is the baseline the other
/// frameworks are measured against.
///
/// Main thread only, like the UI on both ends.
final class AppChannel {
  static let shared = AppChannel()

  private var eventListeners: [UUID: (RepoSearchEvent) -> Void] = [:]
  private var commandListeners: [UUID: (RepoSearchCommand) -> Void] = [:]

  func addEventListener(_ listener: @escaping (RepoSearchEvent) -> Void) -> UUID {
    let id = UUID()
    eventListeners[id] = listener
    return id
  }

  func removeEventListener(_ id: UUID) {
    eventListeners[id] = nil
  }

  func post(_ event: RepoSearchEvent) {
    for listener in eventListeners.values {
      listener(event)
    }
  }

  func addCommandListener(_ listener: @escaping (RepoSearchCommand) -> Void) -> UUID {
    let id = UUID()
    commandListeners[id] = listener
    return id
  }

  func removeCommandListener(_ id: UUID) {
    commandListeners[id] = nil
  }

  func send(_ command: RepoSearchCommand) {
    for listener in commandListeners.values {
      listener(command)
    }
  }
}
