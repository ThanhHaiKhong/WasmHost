//
//  MusicWasm.swift
//  app
//
//  Created by L7Studio on 28/3/25.
//

import AsyncWasmUI
import MusicWasm
import SwiftProtobuf
import WasmSwiftProtobuf
import TaskWasm

extension WasmBuilder {
    static let music = WasmBuilder {
        var ret = try await MusicWasm.default()
        ret.premium = true
        return ret
    }
}
