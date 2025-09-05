//
//  instance.swift
//  WasmHost
//
//  Created by L7Studio on 27/2/25.
//
import Foundation
import WasmSwiftProtobuf

protocol WasmInstance: AnyObject {
    func call(cmd: Data) async throws -> Data
}

public enum EngineState {
    case stopped
    case starting
    case updating(Double)
    case reload(WasmSwiftProtobuf.EngineVersion)
    case running(WasmSwiftProtobuf.EngineVersion)
    case releasing
    case failed(Swift.Error)
}

public protocol WasmInstanceDelegate: AnyObject {
    func stateChanged(state: EngineState)
}
#if os(macOS) || os(watchOS)
import AsyncWasmKit

extension EngineState {
    init(from state: AsyncWasmKit.EngineState) throws {
        switch state {
        case .stopped: self = .stopped
        case .starting: self = .starting
        case let .updating(val): self = .updating(val)
        case let .reload(val): self = .reload(val)
        case let .running(val): self = .running(val)
        case .releasing: self = .releasing
        case let .failed(reason): self = .failed(reason)
        }
    }
}

extension AsyncWasmKit.AsyncifyWasm: WasmInstance {}

extension AsyncWasmEngine: AsyncWasmKit.AsyncifyWasmProvider {
    public func stateChanged(state: AsyncWasmKit.EngineState) {
        do {
            self.delegate?.stateChanged(state: try EngineState(from: state))
        } catch {
            self.delegate?.stateChanged(state: .failed(error))
        }
    }
    public func flowOptions() throws -> AsyncifyOptions? {
        AsyncifyOptions.default()
    }
}

extension AsyncWasmEngine {
    @objc(startWithCompletionHandler:)
    public func start() async throws {
        self._wasm = try AsyncWasmKit.AsyncifyWasm(path: self.url?.path, opts: withAsyncifyWasmDelegate(self), withAsyncifyWasmDir(self.wasmDir), withAsyncifyWasmPoolSize(5))
    }
}
#endif

#if os(iOS)
import MobileFFI

extension MobileFFI.AsyncifyWasm: WasmInstance {}

extension AsyncWasmEngine: MobileFFI.AsyncifyWasmProvider {
    public func stateChanged(state: MobileFFI.EngineState) {
        do {
            self.delegate?.stateChanged(state: try EngineState(from: state))
        } catch {
            self.delegate?.stateChanged(state: .failed(error))
        }
    }
    public func flowOptions() throws -> MobileFFI.FlowOptions {
        MobileFFI.FlowOptions()
    }
    public func updateOptions() throws -> MobileFFI.UpdateOptions {
        MobileFFI.UpdateOptions(bundleDir: "", checkInterval: 60)
    }
    public func setSharedPreferences(key: String, value: Data) {
        // Implementation for shared preferences
    }
    public func getSharedPreferences(key: String) -> Data? {
        // Implementation for shared preferences
        return nil
    }
}

extension AsyncWasmEngine {
    @objc(startWithCompletionHandler:)
    public func start() async throws {
        let asyncifyWasm = MobileFFI.AsyncifyWasm()
        self._wasm = asyncifyWasm
        await asyncifyWasm.start(path: self.url?.path, opts: MobileFFI.Options(wasm: nil, provider: self))
    }
}

// Add EngineState conversion for MobileFFI
extension EngineState {
    init(from state: MobileFFI.EngineState) throws {
        switch state {
        case .stopped: self = .stopped
        case .starting: self = .starting
        case let .updating(val): self = .updating(val)
        case let .reload(val): 
            // Convert MobileFFI.EngineVersion (Data) to WasmSwiftProtobuf.EngineVersion
            let version = try WasmSwiftProtobuf.EngineVersion(serializedData: val)
            self = .reload(version)
        case let .running(val):
            // Convert MobileFFI.EngineVersion (Data) to WasmSwiftProtobuf.EngineVersion  
            let version = try WasmSwiftProtobuf.EngineVersion(serializedData: val)
            self = .running(version)
        case .releasing: self = .releasing
        case let .failed(reason): 
            let error = NSError(domain: "AsyncWasm", code: 0, userInfo: [NSLocalizedDescriptionKey: reason])
            self = .failed(error)
        }
    }
}
#endif
