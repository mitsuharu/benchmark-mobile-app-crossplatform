import XCTest

@testable import NativeApp

/// Covers the home screen's own state: what it does with the events the
/// search screen hands it.
final class HomeModelTests: XCTestCase {
  private var channel: AppChannel!
  private var model: HomeModel!

  override func setUp() {
    super.setUp()
    channel = AppChannel()
    model = HomeModel(channel: channel)
    model.startListening()
  }

  private let repository = SearchedRepository(
    id: 1,
    fullName: "expo/expo",
    stars: 51_842,
    language: "TypeScript"
  )

  func testStartsEmpty() {
    XCTAssertNil(model.lastKeyword)
    XCTAssertNil(model.errorMessage)
    XCTAssertTrue(model.repositories.isEmpty)
  }

  func testKeepsResultsFromASuccessfulSearch() {
    channel.post(.succeeded(keyword: "expo", repositories: [repository]))

    XCTAssertEqual(model.lastKeyword, "expo")
    XCTAssertEqual(model.repositories, [repository])
    XCTAssertNil(model.errorMessage)
  }

  func testAFailureClearsPreviousResults() {
    channel.post(.succeeded(keyword: "expo", repositories: [repository]))

    channel.post(.failed(keyword: "expo", message: "API rate limit exceeded"))

    XCTAssertEqual(model.errorMessage, "API rate limit exceeded")
    XCTAssertTrue(model.repositories.isEmpty)
    XCTAssertEqual(model.lastKeyword, "expo")
  }

  func testASuccessClearsAPreviousFailure() {
    channel.post(.failed(keyword: "expo", message: "boom"))

    channel.post(.succeeded(keyword: "expo", repositories: [repository]))

    XCTAssertNil(model.errorMessage)
    XCTAssertEqual(model.repositories.count, 1)
  }

  func testStopsListeningOnRequest() {
    model.stopListening()

    channel.post(.succeeded(keyword: "expo", repositories: [repository]))

    XCTAssertNil(model.lastKeyword)
  }

  func testEffectiveKeywordFallsBackWhenBlank() {
    model.keyword = "   "
    XCTAssertEqual(model.effectiveKeyword, "expo")

    model.keyword = ""
    XCTAssertEqual(model.effectiveKeyword, "expo")
  }

  func testEffectiveKeywordIsTrimmed() {
    model.keyword = "  swift-format \n"
    XCTAssertEqual(model.effectiveKeyword, "swift-format")
  }
}
