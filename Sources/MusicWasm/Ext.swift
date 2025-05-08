//
//  Ext.swift
//  WasmHost
//
//  Created by L7Studio on 17/2/25.
//
import AsyncWasm
import SwiftUI
import OSLog
import WasmSwiftProtobuf

extension MusicTrack: Identifiable {}

extension MusicTrack {
    public var isPlaylist: Bool { self.kind.hasSuffix("#playlist") }
}
