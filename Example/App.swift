import AsyncWasm
import SwiftUI
import MusicWasm
import AVKit
import OSLog
import Kingfisher
import AsyncWasmUI


@main
struct WASMApp: App {
    
    var builder = WasmBuilder.music
    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(\.wasmBuilder, builder)
        }
    }
}

struct RootView: View {
    @Environment(\.wasmBuilder) var builder
    @State var player = Player()
    @Namespace var animation
    @State var miniOpened = false
    var body: some View {
        NavigationStack {
            MusicScreen(player: player, details: $miniOpened)
                .environment(\.wasmBuilder, builder)
                .task {
                    do {
                        try AVAudioSession.sharedInstance().setCategory(.playback)
                    } catch {
                    }
                }
        }
        .overlay(alignment: .bottom) {
            if let track = self.player.track {
                MiniTrackView(track: track, player: player, details: $miniOpened)
                    .matchedGeometryEffect(id: track.id, in: animation)
            }
        }
    }
}
