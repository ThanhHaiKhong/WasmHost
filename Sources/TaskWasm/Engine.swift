//
//  Engine.swift
//  WasmHost
//
//  Created by L7Studio on 20/3/25.
//

import AsyncWasm
import Foundation
import SwiftProtobuf
import WasmSwiftProtobuf
#if CACHE_WASM_LIST_ACTIONS
import Cache
#endif
extension WaTCallID: CallerID { public func prefix() -> String? {
	"TASK_CALL_ID"
}}
extension WaTTask {
	public var progress: Double? {
		if self.status == .processing {
			return self.metadata["progress"]?.numberValue
		}
		return nil
	}
}
public protocol TaskWasmProtocol: AsyncWasmProtocol {
	
	/// Create task by action
	/// - Parameters:
	///   - action: action
	///   - args: action argument
	/// - Returns: <#description#>
	func create(action: WaTAction, args: [String: Google_Protobuf_Value]) async throws -> WaTTask
	func status(task: WaTTask) async throws -> WaTTask
	func actions() async throws -> WaTListActions
	func actions(for id: String) async throws -> [WaTAction]
}
extension TaskWasmProtocol {
	public func actions<ID>(for id: ID) async throws -> [WaTAction] where ID: RawRepresentable, ID.RawValue == String {
		try await actions(for: id.rawValue)
	}
	/// Create task for first action by id
	/// - Parameters:
	///   - id: action id
	///   - args: run arguments
	/// - Returns: task
	public func create<ID>(id: ID, args: [String: Google_Protobuf_Value] = [:]) async throws -> WaTTask where ID: RawRepresentable, ID.RawValue == String {
		guard let action = try await self.actions(for: id).first else {
			throw NSError(domain: Constants.errorDomain,
						  code: Int(404),
						  userInfo: [NSLocalizedDescriptionKey: "action not found"])
		}
		return try await self.create(action: action, args: args)
	}
	public func data<ID>(id: ID, args: [String: Google_Protobuf_Value] = [:]) async throws -> Data where ID: RawRepresentable, ID.RawValue == String {
		try await self.create(id: id, args: args).value.value
	}
	/// Run a task and cast it to the desired type.
	/// - Parameters:
	///   - id: action id
	///   - args: action arguments
	/// - Returns: unpacked instance
	public func run<ID, T>(id: ID, args: [String: Google_Protobuf_Value] = [:]) async throws -> T where ID: RawRepresentable, ID.RawValue == String, T: Message {
		let task: WaTTask = try await self.create(id: id, args: args)
		guard task.status == .completed else {
			throw NSError(domain: Constants.errorDomain,
						  code: Int(400),
						  userInfo: [NSLocalizedDescriptionKey: "task not completed"])
		}
		return try T(unpackingAny: task.value)
	}
	public func run<T>(action: WaTAction, args: [String: Google_Protobuf_Value] = [:]) async throws -> T where T: Message {
		let task: WaTTask = try await self.create(action: action, args: args)
		guard task.status == .completed else {
			throw NSError(domain: Constants.errorDomain,
						  code: Int(400),
						  userInfo: [NSLocalizedDescriptionKey: "task not completed"])
		}
		return try T(unpackingAny: task.value)
	}
}

public func `default`() async throws -> TaskWasmProtocol {
	TaskWasmEngine()
}
@objc
open class TaskWasmEngine: AsyncWasmEngine, TaskWasmProtocol {
#if CACHE_WASM_LIST_ACTIONS
	static let cacheActionsKey = "task_wasm_actions"
	let diskConfig = DiskConfig(
		name: "WasmEngine",
		expiry: .seconds(60 * 5),
		protectionType: .complete
	)
	lazy var storage = try! Storage<String, Data>(
		diskConfig: diskConfig,
		memoryConfig: MemoryConfig(expiry: .seconds(60 * 5)),
		fileManager: .default,
		transformer: TransformerFactory.forData()
	)
#endif
	public func create(action: WaTAction, args: [String: Google_Protobuf_Value]) async throws -> WaTTask {
		var args = args
		args["provider_id"] = Google_Protobuf_Value(stringValue: action.provider)
		args["action_id"] = Google_Protobuf_Value(stringValue: action.id)
		let caller = try AsyncifyCommand.Call(id: WaTCallID.runAction, args: args)
		return try await cast(grpc_call(AsyncifyCommand(call: caller)))
	}
	public func status(task: WaTTask) async throws -> WaTTask {
		var args = task.metadata.fields
		args["task_id"] = Google_Protobuf_Value(stringValue: task.id)
		args["provider_id"] = Google_Protobuf_Value(stringValue: task.provider)
		let caller = try AsyncifyCommand.Call(id: WaTCallID.getStatus, args: args)
		return try await cast(grpc_call(AsyncifyCommand(call: caller)))
	}
	public func actions() async throws -> WaTListActions {
#if CACHE_WASM_LIST_ACTIONS
		try await storage.async.removeExpiredObjects()
		guard (try? await storage.async.objectExists(forKey: Self.cacheActionsKey)) ?? false else {
			let data = try await self.fetch_actions()
			try await storage.async.setObject(data, forKey: Self.cacheActionsKey)
			return try await cast(data)
		}
		let data = try await storage.async.object(forKey: Self.cacheActionsKey)
		return try await cast(data)
#else
		return try await cast(await self.fetch_actions())
#endif
	}
	public func actions(for id: String) async throws -> [WaTAction] {
		try await actions().actions.filter({ $0.id == id })
	}
	
	@objc(listActionsWithCompletionHandler:)
	public func fetch_actions() async throws -> Data {
		let caller = try AsyncifyCommand.Call(id: WaTCallID.listActions)
		return try await grpc_call(AsyncifyCommand(call: caller))
	}
}
