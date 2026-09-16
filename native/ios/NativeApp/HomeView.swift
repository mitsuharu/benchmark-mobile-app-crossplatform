import SwiftUI

/// The first screen: the keyword is typed here and handed to the search
/// screen, and the results come back over `AppChannel`.
final class HomeModel: ObservableObject {
  @Published var keyword: String = defaultKeyword
  @Published private(set) var lastKeyword: String?
  @Published private(set) var repositories: [SearchedRepository] = []
  @Published private(set) var errorMessage: String?

  static let defaultKeyword = "expo"

  /// The keyword handed to the search screen when it is created.
  var effectiveKeyword: String {
    let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? Self.defaultKeyword : trimmed
  }

  private let channel: AppChannel
  private var listenerID: UUID?

  init(channel: AppChannel = .shared) {
    self.channel = channel
  }

  deinit {
    stopListening()
  }

  func startListening() {
    guard listenerID == nil else { return }
    listenerID = channel.addEventListener { [weak self] event in
      self?.receive(event)
    }
  }

  func stopListening() {
    guard let listenerID else { return }
    channel.removeEventListener(listenerID)
    self.listenerID = nil
  }

  func receive(_ event: RepoSearchEvent) {
    switch event {
    case .succeeded(let keyword, let repositories):
      BenchMarker.mark("resultsReceived")
      self.lastKeyword = keyword
      self.repositories = repositories
      self.errorMessage = nil
    case .failed(let keyword, let message):
      self.lastKeyword = keyword
      self.repositories = []
      self.errorMessage = message
    }
  }
}

/// Where the navigation stack can go.
enum Route: Hashable {
  case repoSearch(keyword: String)
}

struct HomeView: View {
  @StateObject private var model = HomeModel()
  @State private var path: [Route] = []

  var body: some View {
    NavigationStack(path: $path) {
      List {
        Section("検索ワード") {
          TextField("keyword", text: $model.keyword)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .accessibilityIdentifier("keywordField")
        }

        Section("検索画面") {
          // A button rather than a NavigationLink, so the tap itself can be
          // marked: the benchmark measures from here to the screen's first frame.
          Button {
            BenchMarker.mark("searchOpenTapped")
            path.append(.repoSearch(keyword: model.effectiveKeyword))
          } label: {
            Label("検索画面を開く", systemImage: "magnifyingglass")
          }
          .accessibilityIdentifier("openSearch")
        }

        Section("検索画面から受け取った結果") {
          if let errorMessage = model.errorMessage {
            Text(errorMessage).foregroundStyle(.red)
          } else if let lastKeyword = model.lastKeyword {
            LabeledContent("keyword", value: lastKeyword)
            LabeledContent("件数", value: "\(model.repositories.count)")
            ForEach(model.repositories.prefix(3)) { repository in
              LabeledContent(repository.fullName, value: "★ \(repository.stars)")
            }
          } else {
            Text("まだ結果を受け取っていません").foregroundStyle(.secondary)
          }
        }
      }
      .navigationTitle("Home")
      .navigationDestination(for: Route.self) { route in
        switch route {
        case .repoSearch(let keyword):
          RepoSearchView(keyword: keyword, apiBaseURL: AppConfig.apiBaseURL)
            .navigationTitle("Repo Search")
            .navigationBarTitleDisplayMode(.inline)
        }
      }
      .onAppear { BenchMarker.markLaunch() }
    }
    // Attached to the NavigationStack, not the List: pushing a screen makes the
    // List disappear, and the search screen reports its results while it is on top.
    .onAppear { model.startListening() }
    .onDisappear { model.stopListening() }
  }
}

#Preview {
  HomeView()
}
