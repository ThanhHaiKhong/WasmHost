//
//  MusicScreen.swift
//  app
//
//  Created by L7Studio on 10/2/25.
//
import MusicWasm
import SwiftUI
import AsyncWasmUI
import WasmSwiftProtobuf

struct MusicScreen: View {
    @Observable
    class ViewModel {
        var isSearching = false
        var scope = MusicSearchScope.all
        var searchText = ""
        var suggestions: [String] = []
        var tracks: [MusicTrack] = []
        var continuation: String?
        var scopes = MusicSearchScope.allCases
        var discovers = MusicDiscoverCategory.allCases
        @ObservationIgnored var suggestionTask: Task<Void, Swift.Error>?
        @ObservationIgnored var searchTask: Task<Void, Swift.Error>?
        @ObservationIgnored var initialized = false
        func search(engine: WasmEngine<MusicWasmEngine>, version _: EngineVersion, cleanup: Bool = false) {
            if tracks.isEmpty { tracks = [] }
            if cleanup {
                tracks = []
                continuation = nil
            }
            hideKeyboard()
            searchTask?.cancel()
            searchTask = Task.detached {
                let ret = try await engine.instance.search(keyword: self.searchText,
                                                           scope: self.scope,
                                                           continuation: self.continuation)
                await MainActor.run {
                    self.tracks.append(contentsOf: ret.items)
                    self.continuation = ret.hasContinuation ? ret.continuation : nil
                }
            }
        }

        func suggestion(engine: WasmEngine<MusicWasmEngine>, version _: EngineVersion) {
            tracks = []
            continuation = nil
            suggestionTask?.cancel()
            suggestionTask = Task.detached {
                let ret = try await engine.instance.suggestion(keyword: self.searchText).suggestions
                await MainActor.run {
                    self.suggestions = ret
                }
            }
        }

        func onTask(engine _: WasmEngine<MusicWasmEngine>, version _: EngineVersion, isSearching: Bool) async {
            guard !initialized else {
                return
            }
            defer { initialized = true }
            self.isSearching = isSearching
        }
    }

    @Bindable var player: Player
    @Binding var details: Bool
    @Environment(\.wasmBuilder) var builder

    @State var viewModel = ViewModel()

    var body: some View {
        WasmContainerView(engine: player.engine) { version in
            itemsView(version: version)
                .searchable(text: $viewModel.searchText,
                            isPresented: $viewModel.isSearching,
                            prompt: "Search tracks and more...")
                .searchSuggestions {
                    Section {
                        ForEach(viewModel.suggestions, id: \.self) { suggestion in
                            Text(suggestion).searchCompletion(suggestion)
                        }
                    }
                }
                .searchScopes($viewModel.scope) {
                    ForEach(viewModel.scopes, id: \.self) {
                        Text("\($0)").tag($0.rawValue)
                    }
                }
                .onSubmit(of: .search) { viewModel.search(engine: player.engine, version: version, cleanup: true) }
                .onChange(of: viewModel.scope) { viewModel.search(engine: player.engine, version: version, cleanup: true) }
                .onChange(of: viewModel.searchText) { viewModel.suggestion(engine: player.engine, version: version) }
                .task {
                    await viewModel.onTask(engine: player.engine,
                                           version: version,
                                           isSearching: player.bookmarks.items.isEmpty)
                }
        }
    }

    func itemsView(version: EngineVersion) -> some View {
        MiniPlayerOverlayList(player: player, details: $details) {
            if viewModel.isSearching {
                if viewModel.searchText.isEmpty {
                } else {
                    MusicListView.ContentView(player: player,
                                              details: $details,
                                              version: version,
                                              tracks: $viewModel.tracks)
                    if viewModel.continuation != nil {
                        Text("Loading...")
                            .font(.footnote)
                            .task {
                                viewModel.search(engine: player.engine, version: version)
                            }
                    }
                }

            } else {
                Section("Discover") {
                    ForEach(viewModel.discovers, id: \.self) { category in
                        NavigationLink("\(category)".capitalized) {
                            DiscoverView(category: category,
                                         player: player,
                                         details: $details,
                                         version: version)
                        }
                    }
                }
                Section("Bookmarks") {
                    MusicListView.ContentView(player: player,
                                              details: $details,
                                              version: version,
                                              tracks: $player.bookmarks.items)
                }
            }
        }
        .navigationTitle("\(version.name)")
    }
}
