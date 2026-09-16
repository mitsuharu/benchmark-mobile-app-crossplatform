import XCTest

@testable import NativeApp

/// Covers the message bus between the two screens.
final class AppChannelTests: XCTestCase {
  private var channel: AppChannel!

  override func setUp() {
    super.setUp()
    channel = AppChannel()
  }

  private let repository = SearchedRepository(
    id: 65_750_241,
    fullName: "expo/expo",
    stars: 51_842,
    language: "TypeScript"
  )

  func testDeliversEventsToEveryListener() {
    var first: [RepoSearchEvent] = []
    var second: [RepoSearchEvent] = []
    _ = channel.addEventListener { first.append($0) }
    _ = channel.addEventListener { second.append($0) }

    channel.post(.succeeded(keyword: "expo", repositories: [repository]))

    XCTAssertEqual(first.count, 1)
    XCTAssertEqual(second.count, 1)
    guard case .succeeded(let keyword, let repositories) = first[0] else {
      return XCTFail("expected .succeeded, got \(first[0])")
    }
    XCTAssertEqual(keyword, "expo")
    XCTAssertEqual(repositories, [repository])
  }

  func testDeliversNothingAfterTheListenerIsRemoved() {
    var events: [RepoSearchEvent] = []
    let id = channel.addEventListener { events.append($0) }

    channel.removeEventListener(id)
    channel.post(.failed(keyword: "expo", message: "boom"))

    XCTAssertTrue(events.isEmpty)
  }

  func testSendsCommandsToTheScreen() {
    var commands: [RepoSearchCommand] = []
    _ = channel.addCommandListener { commands.append($0) }

    channel.send(.setKeyword("swift"))

    XCTAssertEqual(commands, [.setKeyword("swift")])
  }

  func testSendingWithNoScreenOpenIsHarmless() {
    channel.send(.setKeyword("swift"))
  }

  func testEventsAndCommandsTravelSeparately() {
    var events: [RepoSearchEvent] = []
    var commands: [RepoSearchCommand] = []
    _ = channel.addEventListener { events.append($0) }
    _ = channel.addCommandListener { commands.append($0) }

    channel.send(.setKeyword("swift"))

    XCTAssertTrue(events.isEmpty)
    XCTAssertEqual(commands.count, 1)
  }
}
