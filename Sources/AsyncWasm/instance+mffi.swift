//
//  instance+mffi.swift
//  WasmHost
//
//  Created by L7Studio on 1/4/25.
//
import Foundation
import WasmSwiftProtobuf
import SwiftProtobuf

#if canImport(asyncify_wasmFFI)

import MobileFFI
extension EngineState {
    init(from state: MobileFFI.EngineState) throws {
        switch state {
        case .stopped: self = .stopped
        case .starting: self = .starting
        case let .updating(val): self = .updating(val)
        case let .reload(val): self = .reload(try EngineVersion(serializedBytes: val))
        case let .running(val): self = .running(try EngineVersion(serializedBytes: val))
        case .releasing: self = .releasing
        case let .failed(reason): self = .failed(NSError(domain: Constants.errorDomain, code: -1, userInfo: [NSLocalizedDescriptionKey: reason]))
        }
    }
}

extension AsyncifyWasm: WasmInstance {}

extension AsyncWasmEngine: AsyncifyWasmProvider {
    
    // MARK: - AsyncifyWasmProvider
    public func flowOptions() throws -> FlowOptions {
        var opts = AsyncifyOptions.default()
        opts.premium = self.premium
        for (k, v) in self.copts {
            if let val = String(data: v, encoding: .utf8) {
                opts.extra[k] = Google_Protobuf_Value(stringValue: val)
            }
        }
        return try opts.serializedData()
    }
    public func updateOptions() throws -> UpdateOptions {
        UpdateOptions(bundleDir: self.wasmDir.path, checkInterval: 60)
    }
    public func stateChanged(state: MobileFFI.EngineState) {
        do {
            self.delegate?.stateChanged(state: try EngineState(from: state))
        } catch {
            self.delegate?.stateChanged(state: .failed(error))
        }
    }
    public func setSharedPreferences(key: String, value: Data) {
        UserDefaults.standard.set(value, forKey: key)
    }
    
    public func getSharedPreferences(key: String) -> Data? {
        UserDefaults.standard.data(forKey: key)
    }
    @objc(startWithCompletionHandler:)
    public func start() async throws {
        
#if DEBUG
        let wopts = WasmOptions.wasmtime(target: "pulley64",
                                         memoryReversation: 100 << 20,
                                         memoryReversationForGrowth: 50 << 20,
                                         storeMemorySize: nil,
                                         instancePoolSize: 5
        )
        let opts = Options(wasm: wopts, provider: self)
#else
        let opts = Options(wasm: nil, provider: self)
#endif
        let instance = AsyncifyWasm()
        try await instance.start(path: self.url?.path, opts: opts)
        self._wasm = instance
    }
}

#endif
