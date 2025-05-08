//
//  Engine.swift
//  WasmHost
//
//  Created by L7Studio on 17/2/25.
//
import AsyncWasm
import OSLog
import SwiftProtobuf
import SwiftUI
import WasmSwiftProtobuf

public struct WasmBuilder {
    public var build: @Sendable () async throws -> AsyncWasmProtocol = { fatalError() }
    public init(build: @Sendable @escaping () async throws -> AsyncWasmProtocol = { fatalError() }) {
        self.build = build
    }

    public struct EnvironmentKey: SwiftUI.EnvironmentKey {
        public static let defaultValue = WasmBuilder()
    }
}

public extension EnvironmentValues {
    var wasmBuilder: WasmBuilder {
        get { self[WasmBuilder.EnvironmentKey.self] }
        set {
            self[WasmBuilder.EnvironmentKey.self] = newValue
        }
    }
}

public class WasmEngine<W: AsyncWasmProtocol>: WasmInstanceDelegate, ObservableObject {
    @Published public var state = EngineState.stopped
    public internal(set) var instance: W!
    let defaults = UserDefaults.standard

    public init() throws {}

    /// Load engine actor
    /// - Parameters:
    ///   - builder: engine builder
    public func load(with builder: WasmBuilder, force: Bool = false) async throws {
        guard instance == nil || force else { return }
        guard let val = try await builder.build() as? W else {
            throw Constants.Error.invalidEngineBuilderInstanceType
        }
        instance = val
        instance?.delegate = self
        try await instance?.start()
    }

    public func stateChanged(state: AsyncWasm.EngineState) {
        DispatchQueue.main.async {
            self.state = state
        }
    }
}
