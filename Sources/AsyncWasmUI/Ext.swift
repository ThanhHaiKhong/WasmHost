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

extension EngineVersion: Identifiable {}

extension EngineVersion: RawRepresentable {
    public init?(rawValue: String) {
        try? self.init(jsonString: rawValue)
    }
    
    public var rawValue: String {
        try! self.jsonString()
    }
}
