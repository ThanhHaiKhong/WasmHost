//
//  TaskView.swift
//  app
//
//  Created by L7Studio on 26/3/25.
//
import SwiftUI
import TaskWasm
import AsyncWasm
import AsyncWasmUI
import MusicWasm
import WasmSwiftProtobuf
import SwiftProtobuf

extension WaTAction: @retroactive Identifiable {}

public enum AIImageActionID: String, CaseIterable, Identifiable {
    public var id: String { self.rawValue }
    case autoSuggestion = "0d6339a1-ea1c-432e-b8d5-9bc0f7d5fe09"
    case erase = "c98b41f5-c69b-4dcd-85c0-c01937a56dd9"
    case enhance = "4425e05a-cf76-4f3f-923e-249494e636bf"
    case removeBackground = "1abf881d-23fe-452b-9615-f7c22176e5b3"
    case changeSky = "30eefa03-bf11-4c33-b397-e5d7015a2bfa"
    case tryOn = "75958fa2-978f-41e4-9d4a-a41a645bc59a"
    case categorizeClothes = "4b545ec7-c0f2-40d0-a6c1-ff0c39656f62"
    var formattedName: String {
        "\(self)".replacingOccurrences(of: "([a-z])([A-Z])", with: "$1 $2", options: .regularExpression).capitalized
    }
}

#if DEBUG

extension AIImageActionID {
    func args() -> [String: Google_Protobuf_Value] {
        switch self {
        default:
            return [:]
        }
    }
    func run(engine: WasmEngine<TaskWasmEngine>) async throws -> String {
        switch self {
        default:
            fatalError()
        }
    }
}
@available(iOS 17, macOS 14, tvOS 17, watchOS 10, *)
struct TaskView: View {
    @Observable
    class ViewModel {
        @ObservationIgnored var engine = try! WasmEngine<TaskWasmEngine>()
        var actions: [WaTAction] = []
        func onTask() async {
            await self.loadActions()
        }
        func loadActions() async {
            do {
                self.actions = try await engine.instance.actions().actions
            } catch {
                debugPrint("\(error.localizedDescription)")
            }
        }
        func run(_ actionId: AIImageActionID) async {
            do {
                print("\(try await actionId.run(engine: engine))")
                
            } catch {
                debugPrint("\(error.localizedDescription)")
            }
        }
    }
    @State var viewModel = ViewModel()
    @State var showingListActions = false
    var body: some View {
        WasmContainerView(engine: viewModel.engine) { version in
            NavigationStack {
                List {
                    ForEach(AIImageActionID.allCases) { action in
                        Button(action.formattedName) {
                            Task.detached {
                                await viewModel.run(action)
                            }
                        }
                    }
                }
                .sheet(isPresented: $showingListActions, content: {
                    NavigationView {
                        List {
                            Section("List actions") {
                                ForEach(viewModel.actions) { action in
                                    VStack(alignment: .leading) {
                                        Text("\(action.name)")
                                        Text("\(action.id)").font(.footnote)
                                        ForEach(Array(action.args.keys.enumerated()), id: \.offset) { _,  key in
                                            if let arg = action.args[key] {
                                                Text("\(key)").foregroundStyle(arg.validator.required ? .red : .primary)
                                            }
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                            }
                        }
                        .toolbar {
                            ToolbarItem(placement: .primaryAction) {
                                Button("Close") {
                                    showingListActions.toggle()
                                }
                            }
                        }
                    }
                })
                .toolbar(content: {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Actions") {
                            showingListActions.toggle()
                        }
                    }
                })
            }
            .task {
                await viewModel.onTask()
            }
        }
    }
}

extension WasmBuilder {
    fileprivate static let task = WasmBuilder {
        var ret = try await TaskWasm.default()
        ret.premium = true
        return ret
    }
}
#Preview("TaskView") {
    var builder = WasmBuilder.task
    if #available(iOS 17, *) {
        TaskView()
            .environment(\.wasmBuilder, builder)
    } else {
        // Fallback on earlier versions
    }
}
#endif
