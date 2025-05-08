//
//  MusicListView.swift
//  app
//
//  Created by L7Studio on 7/2/25.
//
import SwiftUI
import AsyncWasm
import OSLog
import WasmSwiftProtobuf

struct MusicListView: View {
    @Environment(\.isSearching) var isSearching
    @Bindable var player: Player
    @Binding var details: Bool
    @State var hasMore: Bool = false
    @State var error: Error?
    @State var tracks: [WasmSwiftProtobuf.MusicTrack] = []
    let version: EngineVersion
    var onFetch:(_ continuation: String?) async throws -> MusicListTracks? = { _ in fatalError() }
    @State var task: Task<Void, Swift.Error>?
    @State private var continuation: String?
    @Environment(\.safeAreaInsets) private var safeAreaInsets
    var body: some View {
        Group {
            if error == nil && self.tracks.isEmpty {
                ProgressView()
            } else {
                MiniPlayerOverlayList(player: player, details: $details) {
                    ContentView(player: player, details: $details, version: version, tracks: $tracks)
                    if hasMore {
                        Text("Loading more...")
                            .font(.footnote)
                            .task {
                                await fetch(refresh: false)
                            }
                    }
                }
            }
        }
        .if(self.error != nil) { view in
            view.overlay {
                MiniPlayerOverlayList(player: player, details: $details) {
                    VStack {
                        Text(self.error!.localizedDescription)
                            .font(.body)
                            .padding()
                        Button("Retry") {
                            self.error = nil
                            self.task?.cancel()
                            self.task = Task {
                                await fetch(refresh: false)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .task {
            await fetch(refresh: false)
        }
        .refreshable {
            await fetch(refresh: true)
        }
    }
    
    func fetch(refresh: Bool) async {
        do {
            self.error = nil
            guard let ret = try await self.onFetch(refresh ? nil : continuation) else { return }
            WALogger.host.debug("found \(ret.items.count) tracks continuation \(ret.continuation)")
            if refresh {
                self.tracks = ret.items
            } else {
                let tracks = ret.items.filter({ item in
                    !self.tracks.contains(where: { $0.id == item.id})}
                )
                self.tracks.append(contentsOf: tracks)
            }
            
            if self.tracks.isEmpty {
                self.error = NSError(domain: "com.l7mobile.wasm.async",
                                     code: Int(400),
                                     userInfo: [NSLocalizedDescriptionKey: "Not found"])
            }
            self.continuation = ret.continuation
            self.hasMore = !ret.continuation.isEmpty
            
        } catch is CancellationError {
        } catch {
            self.error = error
        }
    }
    
    struct ContentView: View {
        @Environment(\.isSearching) var isSearching
        @Bindable var player: Player
        @Binding var details: Bool
        let version: EngineVersion
        @Binding var tracks: [WasmSwiftProtobuf.MusicTrack]
        var body: some View {
            ForEach(self.tracks) { track in
                Group {
                    if track.isPlaylist {
                        NavigationLink(destination: PlaylistView(track: track, player: player, details: $details, version: self.version)) {
                            TrackItemView(track: track)
                        }
                    } else {
                        TrackItemView(track: track)
                            .onTapGesture {
                                withAnimation(.easeIn) {
                                    self.player.track = track
                                }
                            }
                    }
                }
                .swipeActions {
                    if player.bookmarks.contains(track: track) {
                        Button(role: .destructive) {
                            do {
                                try player.bookmarks.remove(track: track)
                            } catch {
                                
                            }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    } else {
                        Button {
                            do {
                                try player.bookmarks.insert(track: track)
                            } catch {
                                
                            }
                        } label: {
                            Label("Bookmark", systemImage: "bookmark")
                        }
                        .tint(.pink)
                    }
                   
                }
            }
        }
    }
}


