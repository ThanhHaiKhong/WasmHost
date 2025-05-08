//
//  manager.swift
//  WasmHost
//
//  Created by L7Studio on 1/4/25.
//
import Foundation
import WasmSwiftProtobuf
actor AsyncifyWasmInternalPool {
    private let maxSize: Int
    private var available: [AsyncifyWasmInternal] = []
    
    init(size: Int) throws {
        self.maxSize = size
    }
    
    func create(wasmPath: String?) throws {
        guard let wasmPath = wasmPath else { return }
        self.release()
        for _ in 0..<self.maxSize {
            let instance = try AsyncifyWasmInternal(path: wasmPath)
            available.append(instance)
        }
    }
    
    func getInstance() async throws -> AsyncifyWasmInternal {
        while available.isEmpty {
            try await Task.sleep(nanoseconds: 100_000_000) // Wait 100ms if no instances available
        }
        return available.removeFirst()
    }
    
    func returnInstance(_ instance: AsyncifyWasmInternal) {
        available.append(instance)
    }
    
    func recreateInstance(wasmPath: String?) throws {
        guard let wasmPath = wasmPath else { return }
        let instance = try AsyncifyWasmInternal(path: wasmPath)
        available.append(instance)
    }
    
    func release() {
        available.removeAll()
    }
}

actor WasmTaskManager {
    static let shared = WasmTaskManager()
    var tasks: [UInt32: Task<Data, Error>] = [:]
    func release() {
        for (_, task) in tasks {
            task.cancel()
        }
        tasks.removeAll()
    }
    
    nonisolated func run(_ task: Task<Data, Error>, key: UInt32) {
        let sema = DispatchSemaphore(value: 0)
        Task {
            defer {
                sema.signal()
            }
            await self._run(task, key: key)
        }
        sema.wait()
    }
    
    private func _run(_ task: Task<Data, Error>, key: UInt32) {
        tasks[key] = Task {
            defer {
                self.tasks.removeValue(forKey: key)
            }
            return try await task.value
        }
    }
}

actor WasmUpdateManager {
    let rootDir: URL
    static let currentVersionKey = "async_wasm_kit_current_version"
    weak var delegate: AsyncifyWasmUpdaterDelegate?
    var isFirstLaunch: Bool = true
    var current: EngineVersion? {
        didSet {
            if current?.hasURL == true, let data = try? current?.serializedData() {
                UserDefaults.standard.set(data, forKey: Self.currentVersionKey)
            }
        }
    }
    init(rootDir: URL) {
        self.rootDir = rootDir
        if let data = UserDefaults.standard.data(forKey: Self.currentVersionKey) {
            if var version = try? EngineVersion(serializedBytes: data) {
                version.url = self.rootDir.appendingPathComponent("\(version.id).wasm").absoluteString
                self.current = version
            }
        }
    }
    func run(delegate: AsyncifyWasmUpdaterDelegate?) throws {
        self.delegate = delegate
        if !FileManager.default.fileExists(atPath: self.rootDir.path) {
            try FileManager.default.createDirectory(at: self.rootDir, withIntermediateDirectories: true)
        }
        startTicker()
    }
    
    func ticker(interval: TimeInterval) -> AsyncStream<Date> {
        return AsyncStream { continuation in
            Task {
                while true {
                    continuation.yield(Date()) // Send current timestamp
                    try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                }
            }
        }
    }
    private func check() async throws {
        guard let version = try await self.delegate?.version() else {
            fatalError("unable to get version")
        }
        if let url = URL(string: version.next.url) {
            let dst = self.rootDir.appendingPathComponent("\(version.next.id).wasm")
            if FileManager.default.fileExists(atPath: dst.path) {
                var next = version.next
                next.url = dst.absoluteString
                self.current = next
                self.delegate?.stateChanged(state: .reload(next))
            } else {
                self.delegate?.stateChanged(state: .updating(0))
                let downloader = AsyncDownloaderSession.shared.download(url: url, destination: dst)
                for try await event in downloader.events {
                    switch event {
                    case let .progress(currentBytes, totalBytes):
                        self.delegate?.stateChanged(state: .updating(Double(currentBytes) / Double(totalBytes)))
                    case let .success(url):
                        var next = version.next
                        next.url = url.absoluteString
                        self.current = next
                        self.delegate?.stateChanged(state: .reload(next))
                    }
                }
            }
        } else if isFirstLaunch {
            self.isFirstLaunch = false
            self.delegate?.stateChanged(state: .reload(version))
        }
    }
    
    private func startTicker() {
        Task {
            for await _ in ticker(interval: 60.0) {
                debugPrint("-- WasmUpdateManager begin check")
                try await check()
                debugPrint("-- WasmUpdateManager finish check")
            }
        }
    }
}
