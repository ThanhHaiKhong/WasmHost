//
//  Bookmarks.swift
//  app
//
//  Created by L7Studio on 11/2/25.
//
import SwiftUI
import MusicWasm
import WasmSwiftProtobuf

@Observable
class BookmarksTrack {
    @ObservationIgnored @AppStorage("bookmarks") var cache = Data()
    var items: [MusicTrack] = []
    
    init() throws {
        if self.cache.isEmpty {
            self.items = [
                try MusicTrack(jsonString: """
                        {"id":"RDEMp7_432lokhimq4eaoILwZA","kind":"youtube#playlist","title":"Mix - Lady Gaga"}
                        """),
                try MusicTrack(jsonString: """
                        {"id":"PLOQtvTOw_3IPhEW9Hl1i1W0SZFjzLGfSm","kind":"youtube#playlist","title":"Lady Gaga - Greatest Hits"}
                        """),
                try MusicTrack(jsonString: """
                        {"id":"PLpR68gbIfkKmrNp3yeVmZRyNR_Lb6XM5Q","kind":"youtube#playlist","title":"6 Longest YouTube Playlist"}
                        """)
                
            ]
        } else {
            self.items.append(contentsOf: try MusicListTracks(jsonUTF8Data: self.cache).items)
        }
        
    }
    func insert(track: MusicTrack) throws {
        self.items.insert(track, at: 0)
        try self.update()
    }
    func contains(track: MusicTrack) -> Bool {
        self.items.contains(where: { $0.id == track.id })
    }
    func remove(track: MusicTrack) throws {
        self.items.removeAll(where: { $0.id == track.id })
        try self.update()
    }
    private func update() throws {
        var list = MusicListTracks()
        list.items = self.items
        cache = try list.jsonUTF8Data()
    }
}
