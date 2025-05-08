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
    case reload(EngineVersion)
    case running(EngineVersion)
    case releasing
    case failed(Swift.Error)
}

public protocol WasmInstanceDelegate: AnyObject {
    func stateChanged(state: EngineState)
}
#if canImport(AsyncWasmKit)
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

extension AsyncifyWasm: WasmInstance {}

extension AsyncWasmEngine: AsyncifyWasmProvider {
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
    
    @objc(startWithCompletionHandler:)
    public func start() async throws {
        self._wasm = try AsyncifyWasm(path: self.url?.path, opts: withAsyncifyWasmDelegate(self), withAsyncifyWasmDir(self.wasmDir), withAsyncifyWasmPoolSize(5))
    }
}
#endif
