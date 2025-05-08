//
//  ext.swift
//  WasmHost
//
//  Created by L7Studio on 18/2/25.
//
import Foundation

extension UInt32 {
    var hex: String {
        "0x" + String(self, radix: 16)
    }
}
