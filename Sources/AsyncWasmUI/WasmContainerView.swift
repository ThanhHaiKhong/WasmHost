//
//  WasmContainerView.swift
//  app
//
//  Created by L7Studio on 10/2/25.
//
import AsyncWasm
import OSLog
import SwiftUI
import WasmSwiftProtobuf

public struct WasmContainerView<ContentView: View, W: AsyncWasmProtocol>: View {
    @ObservedObject var engine: WasmEngine<W>
    @ViewBuilder var contentView: (EngineVersion) -> ContentView
    @Environment(\.wasmBuilder) var builder
    public init(engine: WasmEngine<W>,
                contentView: @escaping (EngineVersion) -> ContentView) {
        self.engine = engine
        self.contentView = contentView
    }
    func load(force: Bool) async {
        do {
            try await self.engine.load(with: builder, force: force)
        } catch {
            self.engine.state = .failed(error)
        }
    }
    public var body: some View {
        VStack {
            switch engine.state {
            case .stopped, .starting:
                ProgressView()
            case let .updating(val):
                ProgressView(value: val) {
                    Text("Downloading ...")
                }
                .progressViewStyle(.linear)
                .padding()
            case let .reload(ver):
                ProgressView() {
                    Text("Reloading \(ver.name)...")
                }
                .padding()
            case let .running(version):
                contentView(version)
            case .releasing:
                EmptyView()
            case let .failed(error):
                ScrollView {
                    VStack {
                        Text(error.localizedDescription)
                            .font(.body)
                            .padding()
                        Button("Retry") {
                            Task.detached {
                                await load(force: true)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
        }
        .task {
            await load(force: false)
        }
    }

}
