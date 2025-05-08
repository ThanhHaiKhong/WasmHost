//
//  ws.swift
//  host
//
//  Created by L7Studio on 6/2/25.
//

import Foundation
import CryptoKit
import WasmSwiftProtobuf

func backoff(attempts: Int) -> TimeInterval {
    if attempts > 13 {
        return 2 * 60
    }
    let delay = pow(Double(attempts), M_E) * 0.1
    return delay
}
actor WebSocketManager {
    
    class Connection {
        var task: URLSessionWebSocketTask?
        let req: URLRequest
        weak var session: URLSession?
        var attempts = 0
        enum State { case connecting, connected, disconnected }
        var state = State.connecting
        var receive: (Data?) throws -> Void = {_ in }
        let lock = NSLock()
        init(req: URLRequest) {
            self.req = req
        }
        func send(data: Data) async throws -> AsyncifyCommand.Sync.WebSocket {
            var attempts = 0
            while self.state != .connected {
                attempts += 1
                debugPrint("wait connenction to send data")
                try await Task.sleep(nanoseconds: UInt64(backoff(attempts: attempts) * 1e9))
            }
            return try await withCheckedThrowingContinuation { continuation in
                task?.send(URLSessionWebSocketTask.Message.data(data)) { error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(with: .success(AsyncifyCommand.Sync.WebSocket()))
                    }
                }
            }
        }

        func connect(session: URLSession) throws {
            self.lock.lock()
            defer { self.lock.unlock()}
            debugPrint("connecting")
            self.state = .connecting
            self.task = session.webSocketTask(with: req)
            self.task?.resume()
            self.listen()
            self.task?.sendPing(pongReceiveHandler: { error in
                if let _ = error {
                } else {
                    self.lock.lock()
                    self.attempts = 0
                    self.state = .connected
                    self.lock.unlock()
                    debugPrint("connected")
                }
            })
        }
        func listen() {
            task?.receive { result in
                do {
                    switch result {
                    case .success(let message):
                        switch message {
                        case .string(let text):
                            try self.receive(text.data(using: .utf8))
                        case .data(let data):
                            try self.receive(data)
                        @unknown default:
                            debugPrint("Unknown message format received")
                        }
                        self.listen()
                    case .failure(let error):
                        try self.retry(error: error)
                    }
                   
                } catch {
                    try? self.retry(error: error)
                }
            }
        }
        
        func retry(error: Error) throws {
            self.lock.lock()
            attempts += 1
            self.lock.unlock()
            debugPrint("[ws] \(attempts) retry for \(error.localizedDescription)")
            Thread.sleep(forTimeInterval: backoff(attempts: attempts))
            self.disconnect()
            if let session {
                try self.connect(session: session)
            }
        }
        
        func disconnect() {
            task?.cancel(with: .goingAway, reason: nil)
        }
    }
    
    static let shared = WebSocketManager()
    let urlSession = URLSession(configuration: .default)
    private var conns: [String: Connection] = [:]
    
    func connection(for req: URLRequest) throws -> Connection {
        return Connection(req: req)
    }
    
    func connect(req: URLRequest) throws -> Connection {
        let key = self.hash(req)
        if let conn = self.conns[key] {
            return conn
        }
        let conn = try self.connection(for: req)
        conn.session = urlSession
        try conn.connect(session: urlSession)
        self.conns[key] = conn
        return conn
    }
    
    private func hash(_ req: URLRequest) -> String {
        let inputData = Data(req.url!.absoluteString.utf8)
        let digest = Insecure.MD5.hash(data: inputData)
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }
    
}
