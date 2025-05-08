//
//  PlaylistView.swift
//  app
//
//  Created by L7Studio on 7/2/25.
//

import OSLog
import SwiftUI
import WasmSwiftProtobuf

struct PlaylistView: View {
    let track: WasmSwiftProtobuf.MusicTrack
    @Bindable var player: Player
    @Binding var details: Bool
    let version: EngineVersion
    var body: some View {
        MusicListView(player: player,
                      details: $details,
                      version: version,
                      onFetch: fetch)
            .navigationTitle(track.title)
    }

    func fetch(_ continuation: String?) async throws -> MusicListTracks? {
        try await player.engine.instance.tracks(pid: track.id,
                                                continuation: continuation)
    }
}
