import Foundation
import SwiftProtobuf
import SystemPackage
import WasmKit
import WasmSwiftProtobuf
#if canImport(UIKit)
import UIKit
#endif
#if os(watchOS)
import WatchKit
#endif
public struct Options {
    weak var delegate: AsyncifyWasmProvider?
    var poolSize: Int = 5
    var wasmDir: URL?
}
public typealias Option = (inout Options) -> Void
public func withAsyncifyWasmDelegate<T: AsyncifyWasmProvider>(_ delegate: T) -> Option {
    return { opts in
        opts.delegate = delegate
    }
}
public func withAsyncifyWasmPoolSize(_ poolSize: Int) -> Option {
    return { opts in
        opts.poolSize = poolSize
    }
}
public func withAsyncifyWasmDir(_ wasmDir: URL) -> Option {
    return { opts in
        opts.wasmDir = wasmDir
    }
}
public enum EngineState {
    case stopped
    case starting
    case updating(Double)
    case reload(EngineVersion)
    case running(EngineVersion)
    case releasing
    case failed(Swift.Error)
}
public protocol AsyncifyWasmProvider: AnyObject {
    func flowOptions() throws -> AsyncifyOptions?
    func stateChanged(state: EngineState)
}
protocol AsyncifyWasmUpdaterDelegate: AsyncifyWasmProvider {
    func version() async throws -> EngineVersion
}
public class AsyncifyWasm: AsyncifyWasmUpdaterDelegate {
    let _opts: Options
    let updater: WasmUpdateManager
    let pool: AsyncifyWasmInternalPool
    var wasmPath: String? {
        get async {
            if let version = await self.updater.current {
                return version.url.replacingOccurrences(of: "file://", with: "")
            }
            return nil
        }
    }
    public init(path: String?, opts: Option...) throws {
        var optsStruct = Options()
        for o in opts {
            o(&optsStruct)
        }
        self._opts = optsStruct
        self.pool = try AsyncifyWasmInternalPool(size: optsStruct.poolSize)
        self.updater = WasmUpdateManager(rootDir: optsStruct.wasmDir ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.appendingPathComponent("wasm"))
        Task.detached {
            let recentPath = await self.wasmPath
            try await self.pool.create(wasmPath: recentPath ?? path ?? Bundle.module.path(forResource: "base", ofType: "wasm")!)
            try await self.updater.run(delegate: self)
        }
    }
    
    public func call(cmd: Data) async throws -> Data {
        let wasm = try await pool.getInstance()
        do {
            let ret = try await wasm.call(cmd: cmd)
            await pool.returnInstance(wasm)
            return ret
        } catch {
            if let _ = error as? WasmKit.Trap {
                await wasm.release()
                try await pool.recreateInstance(wasmPath: self.wasmPath)
            } else {
                await pool.returnInstance(wasm)
            }
            throw error
        }
    }
    
    public func stateChanged(state: EngineState) {
        Task.detached {
            await MainActor.run {
                self._opts.delegate?.stateChanged(state: state)
            }
            if case let .reload(version) = state {
                try await self.pool.create(wasmPath: self.wasmPath)
                self._opts.delegate?.stateChanged(state: .running(version))
            }
        }
    }
    
    public func flowOptions() throws -> AsyncifyOptions? {
        try self._opts.delegate?.flowOptions()
    }
    
    public func release() async {
        await pool.release()
    }
    
}
enum AsyncifyWasmError: Error {
    case missingFlowOptions
}
extension AsyncifyWasm {
    func cast<T>(_ data: Data) async throws -> T where T: SwiftProtobuf.Message {
        return try T(serializedBytes: data)
    }
    
    func call<T>(_ cmd: AsyncifyCommand) async throws -> T where T: SwiftProtobuf.Message {
        try await cast(await grpc_call(cmd))
    }
    func grpc_call(_ cmd: AsyncifyCommand) async throws -> Data {
        try await call(cmd, contentType: "application/grpc")
    }
    private func call(_ cmd: AsyncifyCommand, contentType: String) async throws -> Data {
        var cmd = cmd
        cmd.options.contentType = contentType
        return try await call(cmd: cmd.serializedData())
    }
    func version() async throws -> EngineVersion {
        var caller = AsyncifyCommand.Call()
        caller.id = "ENGINE_CALL_ID_GET_VERSION"
        guard var opts = try self.flowOptions() else {
            throw AsyncifyWasmError.missingFlowOptions
        }
        opts.uid = "c26b9659-e3ba-40b4-b993-bed11ced0457"
        var cmd = AsyncifyCommand(call: caller)
        cmd.options = opts
        return try await call(cmd)
    }
}
extension AsyncifyCommand {
    public init(call: Call) {
        self.init()
        self.requestID = UUID().uuidString
        self.kind = .call
        self.call = call
    }
}

class AsyncifyWasmInternal {
    let instance: Instance
    public init(path: String) throws {
        let module = try parseWasm(filePath: SystemPackage.FilePath(path))
        let engine = Engine()
        let store = Store(engine: engine)
        var imports = Imports()
        
        imports.define(module: "asyncify", name: "log", Function(
            store: store,
            parameters: [.i32, .i32],
            results: [],
            body: { caller, args in
                assert(args.count == 2)
                let memory = caller.instance!.exports[memory: "memory"]!
                let msg = memory.string(fromByteOffset: args[0].i32, len: Int(args[1].i32)) ?? ""
                debugPrint(msg)
                return []
            }
        ))
        imports.define(module: "asyncify", name: "epoch_time", Function(
            store: store,
            parameters: [.i32],
            body: { caller, args in
                assert(args.count == 1)
                let outPtr = args[0].i32
                let memory = caller.instance!.exports[memory: "memory"]!
                try memory.copy(from: "\(Date().timeIntervalSince1970)".to_wa(in: caller.instance!), to: outPtr)
                return []
            }
        ))
        imports.define(module: "asyncify", name: "usleep", Function(
            store: store,
            parameters: [.i32],
            body: { _, args in
                assert(args.count == 2)
                debugPrint("sleeping \(args[0].i32) us")
                usleep(args[0].i32)
                return []
            }
        ))
        imports.define(module: "asyncify", name: "uuid_v4", Function(
            store: store,
            parameters: [.i32],
            body: { caller, args in
                assert(args.count == 1)
                let outPtr = args[0].i32
                let memory = caller.instance!.exports[memory: "memory"]!
                try memory.copy(from: UUID().uuidString.to_wa(in: caller.instance!), to: outPtr)
                return []
            }
        ))
        imports.define(module: "asyncify", name: "deciph", Function(
            store: store,
            parameters: [.i32, .i32, .i32],
            results: [],
            body: { caller, args in
                assert(args.count == 3)
                let outPtr = args[0].i32
                let memory = caller.instance!.exports[memory: "memory"]!
                let ciphered = memory.data(fromByteOffset: args[1].i32, len: Int(args[2].i32))
                let deciphered = auth_decipher_from_hex(value: ciphered)
                try memory.copy(from: String(data: deciphered, encoding: .utf8)?.to_wa(in: caller.instance!), to: outPtr)
                return []
            }
        ))
        imports.define(module: "asyncify", name: "ciph", Function(
            store: store,
            parameters: [.i32, .i32, .i32],
            results: [],
            body: { caller, args in
                assert(args.count == 3)
                let outPtr = args[0].i32
                let memory = caller.instance!.exports[memory: "memory"]!
                let plain = memory.data(fromByteOffset: args[1].i32, len: Int(args[2].i32))
                let ciphered = auth_cipher_to_hex(value: plain)
                try memory.copy(from: ciphered, to: outPtr)
                return []
            }
        ))
        imports.define(module: "asyncify", name: "get", Function(
            store: store,
            parameters: [.i32, .i32],
            results: [],
            body: { caller, args in
                measure(msg: "get") {
                    // parameters: output, offset
                    assert(args.count == 2)
                    
                    let outPtr = args[0].i32
                    let memory = caller.instance!.exports[memory: "memory"]!
                    let deallocator = caller.instance!.exports[function: "release"]!
                    let input = memory.load(fromByteOffset: args[1].i32, as: WAFuture.self)
                    let sema = DispatchSemaphore(value: 0)
                    Task(priority: .userInitiated) {
                        debugPrint("[\(outPtr.hex)] started")
                        defer {
                            sema.signal()
                        }
                        let argsPtr = try await input.args(with: caller.instance!,
                                                           outPtr: outPtr,
                                                           fnPtr: 0,
                                                           callback: false)
                        do {
                            try deallocator([.i32(argsPtr[0])])
                        } catch {}
                    }
                    sema.wait()
                    debugPrint("[\(outPtr.hex)] finished")
                    return []
                }
            }
        ))
        imports.define(module: "asyncify", name: "get_async", Function(
            store: store,
            parameters: [.i32, .i32, .i32],
            results: [],
            body: { caller, args in
                try measure(msg: "get_async") {
                    // parameters: output, fn, offset
                    assert(args.count == 3)
                    
                    let outPtr = args[0].i32
                    let fnPtr = args[1].i32
                    let memory = caller.instance!.exports[memory: "memory"]!
                    let input = memory.load(fromByteOffset: args[2].i32, as: WAFuture.self)
                    // save context to output
                    try memory.copy(
                        from: WAFuture(
                            data: 0,
                            len: 0,
                            callback: fnPtr,
                            context: input.context,
                            context_len: input.context_len,
                            // store `index` with value is `output` pointer to run task after
                            index: outPtr
                        ), to: outPtr
                    )
                    debugPrint("[\(outPtr.hex)] enqueue task \(args.map { $0.i32.hex })")
                    debugPrint("[\(outPtr.hex)] input <\(args[2].i32.hex)> \(input.debugDescription)")
                    WasmTaskManager.shared.run(Task(priority: .background) {
                        // - store tasks with key `outPtr`
                        debugPrint("[\(outPtr.hex)] async started")
                        defer {
                            debugPrint("[\(outPtr.hex)] async finished")
                        }
                        let deallocator = caller.instance!.exports[function: "release"]!
                        let memory = caller.instance!.exports[memory: "memory"]!
                        let callback = caller.instance!.exports[function: "callback"]!
                        try Task.checkCancellation()
                        let argsPtr = try await input.args(with: caller.instance!,
                                                           outPtr: outPtr,
                                                           fnPtr: fnPtr,
                                                           callback: true)
                        try Task.checkCancellation()
                        // execute `fn`
                        try callback([.i32(outPtr), .i32(fnPtr), .i32(argsPtr[0])])
                        try Task.checkCancellation()
                        let result = memory.load(fromByteOffset: outPtr, as: WAFuture.self)
                        var val: Data
                        // wasm call another async `get` function
                        if result.callback != 0 && result.index != 0 {
                            debugPrint("[\(outPtr.hex)] call child \(result.index.hex)")
                            val = try await WasmTaskManager.shared.tasks[result.index]!.value
                        } else {
                            val = result.data(in: memory)
                            do {
                                try deallocator([.i32(outPtr)])
                            } catch {}
                            if result.data != 0 {
                                do {
                                    try deallocator([.i32(result.data)])
                                } catch {}
                            }
                        }
                        do {
                            try deallocator([.i32(argsPtr[0])])
                            try deallocator([.i32(argsPtr[1])])
                        } catch {}
                        debugPrint("[\(outPtr.hex)] dequeue task")
                        return val
                    }, key: outPtr)
                    return []
                }
            })
        )
        
        instance = try module.instantiate(store: store, imports: imports)
    }
    
    /// call with input to caller wasm
    /// caller:
    /// - args: ouput, input_ptr, input_len
    public func call(cmd: Data) async throws -> Data {
        let caller = instance.exports[function: "call"]!
        let allocator = instance.exports[function: "allocate"]!
        let deallocator = instance.exports[function: "release"]!
        let memory = instance.exports[memory: "memory"]!
        let outPtr = try allocator([.i32(UInt32(MemoryLayout<WAFuture>.size))])[0].i32
        // copy input to heap
        let inputPtr = try memory.set(data: cmd, in: allocator)
        try caller([.i32(outPtr), .i32(inputPtr), .i32(UInt32(cmd.count))])
        // extract `outPtr`
        let result = memory.load(fromByteOffset: outPtr, as: WAFuture.self)
        try Task.checkCancellation()
        if result.index != 0, let task = await WasmTaskManager.shared.tasks[result.index] {
            return try await task.value
        }
        defer {
            // clean
            do {
                try deallocator([.i32(outPtr)])
                try deallocator([.i32(inputPtr)])
            } catch {}
            // - check error
        }
        return result.data(in: memory)
    }
    
    public func release() async {
        await WasmTaskManager.shared.release()
    }
    
    deinit {
        debugPrint("wasm deinit")
    }
}
