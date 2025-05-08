//
//  Memory.swift
//  AsyncWasm
//
//  Created by L7Studio on 23/12/24.
//

import Foundation
import WasmKit

extension Memory {
    func load<T>(fromByteOffset offset: UInt32 = 0, as type: T.Type) -> T {
        withUnsafeMutableBufferPointer(offset: UInt(offset), count: MemoryLayout<T>.size) { ptr in
            ptr.load(as: type)
        }
    }
    func load<T>(fromByteOffset offset: UInt32 = 0, len: UInt32, as type: T.Type) -> [T] {
        (0..<len).map {
            withUnsafeMutableBufferPointer(
                offset: UInt(offset + $0 * UInt32(MemoryLayout<T>.size)), count: MemoryLayout<T>.size
            ) { ptr in
                ptr.load(as: type)
            }
        }
    }
    func string(fromByteOffset offset: UInt32, len: Int) -> String? {
        data.withUnsafeBufferPointer { ptr in
            guard let baseAddress = ptr.baseAddress else {
                return nil
            }
            return String(
                bytesNoCopy: UnsafeMutableRawPointer(mutating: baseAddress.advanced(by: Int(offset))),
                length: len,
                encoding: .utf8,
                freeWhenDone: false)
        }
    }
    
    func data(fromByteOffset offset: UInt32, len: Int ) -> Data {
        data.withUnsafeBufferPointer { ptr in
            Data(
                bytesNoCopy: UnsafeMutableRawPointer(mutating: ptr.baseAddress!.advanced(by: Int(offset))),
                count: len,
                deallocator: .none)
            // Data(bytes: ptr.baseAddress!.advanced(by: Int(offset)), count: len)
        }
    }
    
    func set(string val: String, in allocator: Function) throws -> UInt32 {
        let vlen = val.utf8.count + 1
        let vptr = try allocator([.i32(UInt32(MemoryLayout<UInt8>.size * vlen))])[0].i32
        withUnsafeMutableBufferPointer(offset: UInt(vptr), count: vlen) { ptr in
            val.utf8CString.withUnsafeBytes { bytes in
                ptr.copyMemory(from: bytes)
            }
        }
        return vptr
    }
    
    func set(data val: Data, in allocator: Function, file: String = #file, line: Int = #line) throws
    -> UInt32
    {
        let vlen = val.count
        let vptr = try allocator([.i32(UInt32(MemoryLayout<UInt8>.size * vlen))])[0].i32
        withUnsafeMutableBufferPointer(offset: UInt(vptr), count: vlen) { ptr in
            val.withUnsafeBytes { bytes in
                ptr.copyMemory(from: bytes)
            }
        }
        return vptr
    }
    func set<T>(val: T, in allocator: Function) throws -> UInt32 {
        let vlen = MemoryLayout<T>.size
        let vptr = try allocator([.i32(UInt32(vlen))])[0].i32
        try self.copy(from: val, to: vptr)
        return vptr
    }
    func set<T>(val: [T], in allocator: Function) throws -> UInt32 {
        let vlen = MemoryLayout<T>.size * val.count
        let vptr = try allocator([.i32(UInt32(vlen))])[0].i32
        for (o, v) in val.enumerated() {
            try self.copy(from: v, to: vptr + UInt32(o * MemoryLayout<T>.size))
        }
        return vptr
    }
    func copy<T>(from: T, to: UInt32) throws {
        withUnsafeMutableBufferPointer(offset: UInt(to), count: MemoryLayout<T>.size) { ptr in
            withUnsafeBytes(of: from) { bytes in
                ptr.copyMemory(from: bytes)
            }
        }
    }
}
