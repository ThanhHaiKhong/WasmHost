//
//  structs.swift
//  WasmHost
//
//  Created by L7Studio on 31/12/24.
//
import WasmKit
import Foundation

struct WAString: WAPointer {
    let data: UInt32
    let len: UInt32
    func string(in memory: Memory) -> String? {
        memory.string(fromByteOffset: data, len: Int(len))
    }
}

protocol WAPointer {}

extension WAPointer {
    func to_wa_ptr(in instance: Instance) throws -> UInt32 {
        let memory = instance.exports[memory: "memory"]!
        let allocator = instance.exports[function: "allocate"]!
        return try memory.set(val: self, in: allocator)
    }
}
extension String {
    func to_wa(in instance: Instance) throws -> WAString {
        let memory = instance.exports[memory: "memory"]!
        let allocator = instance.exports[function: "allocate"]!
        return WAString(data: try memory.set(string: self, in: allocator), len: UInt32(self.count))
    }
    func to_wa_ptr(in instance: Instance) throws -> UInt32 {
        try self.to_wa(in: instance).to_wa_ptr(in: instance)
    }
}
