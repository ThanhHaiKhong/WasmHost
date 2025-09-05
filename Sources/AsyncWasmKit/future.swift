//
//  Future.swift
//  AsyncWasm
//
//  Created by L7Studio on 23/12/24.
//
import Foundation
import WasmKit
import OSLog

/// In WASM memory the future is just an array of 6 `i32` (total size 24 bytes)
struct WAFuture {
    /// contains wasm command
    let data: UInt32
    let len: UInt32
    let callback: UInt32
    /// the `context` pointer (and associated length) is for the guest to use as necessary,
    /// and it is the guest's responsibility to copy it across if it creates a new future instance
    let context: UInt32
    let context_len: UInt32
    /// The `index` field is used to pass a map key from the host `get()` to the host `callback()`
    /// - the guest code (WASM) doesn't need to and shouldn't use it
    let index: UInt32
    
    init(
        data: UInt32,
        len: UInt32,
        callback: UInt32,
        context: UInt32,
        context_len: UInt32,
        index: UInt32
    ) {
        self.data = data
        self.len = len
        self.callback = callback
        self.context = context
        self.context_len = context_len
        self.index = index
    }
    
    func data(in memory: Memory) -> Data {
        memory.data(fromByteOffset: self.data, len: Int(self.len))
    }
    
    func context(in memory: Memory) -> Data {
        memory.data(fromByteOffset: self.context, len: Int(self.context_len))
    }
    @discardableResult
    func debugDescription(in memory: Memory, prefix: String = "", file: String = #file, line: Int = #line, log: OSLog = .default)  -> Self {
#if DEBUG
        let args = [
            "\((file as NSString).lastPathComponent)#L\(line)",
            prefix,
        """
WAFuture<
    data: \(memory.string(fromByteOffset: self.data, len: Int(self.len)) ?? "null"),
    context: \(memory.string(fromByteOffset: self.context, len: Int(self.context_len)) ?? "null"),
    callback: \(self.callback),
    index: \(self.index)
>
"""].filter({ !$0.isEmpty })
        if #available(macOS 11.0, iOS 14.0, watchOS 7.0, *) {
            os_log(.debug, log: log, "\(args.joined(separator: " "))")
        } else {
            print(args.joined(separator: " "))
        }
#endif
        return self
    }
}

extension WAFuture: CustomDebugStringConvertible {
    var debugDescription: String {
        "WAFuture(data: \(self.data.hex), len: \(self.len), callback: \(self.callback.hex), context: \(self.context.hex), context_len: \(self.context_len), index: \(self.index.hex))"
    }
}
