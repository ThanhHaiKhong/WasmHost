//
//  DiscoverView.swift
//  app
//
//  Created by L7Studio on 7/2/25.
//

import MusicWasm
import SwiftUI
import WasmSwiftProtobuf

struct DiscoverView: View {
    let category: MusicDiscoverCategory
    @Bindable var player: Player
    @Binding var details: Bool
    let version: EngineVersion
    var body: some View {
        MusicListView(player: player,
                      details: $details,
                      version: version,
                      onFetch: fetch)
            .navigationTitle("\(category)".capitalized)
    }

    func fetch(_ continuation: String?) async throws -> MusicListTracks? {
        try await player.engine.instance.discover(category: category,
                                                  continuation: continuation)
    }
}
