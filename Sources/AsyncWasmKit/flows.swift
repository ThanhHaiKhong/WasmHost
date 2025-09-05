//
//  flows.swift
//  WasmHost
//
//  Created by L7Studio on 26/12/24.
//
import Foundation
import SwiftProtobuf
import UniformTypeIdentifiers
import WasmSwiftProtobuf
import WasmKit
#if canImport(JavaScriptCore)
import JavaScriptCore
#endif
#if canImport(CoreGraphics)
import CoreGraphics
#endif
#if canImport(ImageIO)
import ImageIO
#endif
#if canImport(AVFoundation)
import AVFoundation
#endif
extension WAFuture {
    ///  Process future
    /// - Parameters:
    ///   - instance: wasm instance
    ///   - outPtr: out pointer
    ///   - callback: indicate wait child callback
    /// - Returns: pointers need to be free
    @discardableResult
    func args(with instance: Instance, outPtr: UInt32, fnPtr: UInt32, callback: Bool) async throws -> [UInt32] {
        let allocator = instance.exports[function: "allocate"]!
        let memory = instance.exports[memory: "memory"]!
        let cmd = try AsyncifyCommand(
            serializedBytes: memory.data(fromByteOffset: data, len: Int(len)))
        try debugPrint("[\(outPtr.hex)] delegate \(cmd.jsonString())")
        // required delegate action
        guard case let .delegate(act) = cmd.data else { fatalError() }
        let offset = try await {
            switch act.action {
            case let .http(val):
                let session = URLSession.shared
                
                var req = URLRequest(url: URL(string: val.url)!)
                req.httpMethod = val.method
                for (k, v) in val.headers {
                    req.setValue(v, forHTTPHeaderField: k)
                }
                let cookies = val.cookies.reduce(
                    [HTTPCookie?]())
                {
                    var ret: [HTTPCookiePropertyKey: Any] = [:]
                    if $1.hasDomain {
                        ret[.domain] = $1.domain
                    }
                    if $1.hasPath {
                        ret[.path] = $1.path
                    }
                    ret[.name] = $1.name
                    ret[.value] = $1.value
                    
                    if $1.hasSecure {
                        ret[.secure] = $1.secure
                    }
                    return $0 + [HTTPCookie(properties: ret)]
                }
                for cookie in cookies.compactMap({ $0 }) {
                    HTTPCookieStorage.shared.setCookie(cookie)
                }
                req.httpShouldHandleCookies = true
                if val.hasBody {
                    req.httpBody = val.body.bytes
                } else if !val.multiparts.isEmpty {
                    let boundary = "Boundary-\(UUID().uuidString)"
                    let lineBreak = "\r\n"
                    var buf = Data()
                    for part in val.multiparts {
                        if part.value.hasPrefix("file://") {
                            if let fileURL = URL(string: part.value),
                               FileManager.default.fileExists(atPath: fileURL.path)
                            {
                                buf.append("--\(boundary)\(lineBreak)")
                                buf.append(
                                    "Content-Disposition: form-data; name=\"\(part.field)\"; filename=\"\(part.filename)\"\(lineBreak)"
                                )
                                buf.append(
                                    "Content-Type: \(fileURL.pathExtension.mimeType())\(lineBreak)\(lineBreak)")
                                // https://github.com/Alamofire/Alamofire/blob/98c28e683253e920f5220d4456c5e4a6da7aa941/Source/MultipartFormData.swift#LL375C5-L375C12
                                if let inputStream = InputStream(url: fileURL) {
                                    inputStream.open()
                                    defer {
                                        inputStream.close()
                                    }
                                    var encoded = Data()
                                    let streamBufferSize = 1024
                                    while inputStream.hasBytesAvailable {
                                        var buffer = [UInt8](repeating: 0, count: streamBufferSize)
                                        let bytesRead = inputStream.read(&buffer, maxLength: streamBufferSize)
                                        
                                        if let error = inputStream.streamError {
                                            fatalError("input stream read failed \(error.localizedDescription)")
                                        }
                                        if bytesRead > 0 {
                                            encoded.append(buffer, count: bytesRead)
                                        } else {
                                            break
                                        }
                                    }
                                    // if let compressedData = try? NSData(data: encoded).compressed(using: .zlib) as Data {
                                    //   body.append(compressedData)
                                    // }
                                    buf.append(encoded)
                                    // body.append(try Data(contentsOf: fileURL))
                                }
                                buf.append("\(lineBreak)")
                            }
                        } else {
                            buf.append("--\(boundary)\(lineBreak)")
                            buf.append(
                                "Content-Disposition: form-data; name=\"\(part.field)\"\(lineBreak)\(lineBreak)")
                            buf.append("\(part.value)\(lineBreak)")
                        }
                    }
                    buf.append("--\(boundary)--\(lineBreak)")
                    req.httpBody = buf
                    req.setValue(
                        "multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type"
                    )
                }
                return try await session.command(for: req, id: cmd.requestID, usePtr: true, instance: instance)
            case let .regex(regex):
                return try regex.command(for: cmd.requestID, memory: memory)
                
            case let .js(js):
                return try js.command(for: cmd.requestID)
            case let .ws(ws):
                return try await ws.command(for: cmd.requestID, fnPtr: fnPtr, instance: instance)
            case let .fd(fd):
                return try await fd.command(for: cmd.requestID)
            default:
                fatalError()
            }
        }()
        let offsetData = try offset.serializedData()
        let offsetPtr = try memory.set(data: offsetData, in: allocator)
        let offsetLen = UInt32(offsetData.count)
        let argsPtr = try allocator([.i32(UInt32(MemoryLayout<WAFuture>.size))])[0].i32
        if callback {
            // - fill args
            try memory.copy(
                from: WAFuture(
                    data: offsetPtr,
                    len: offsetLen,
                    callback: 0,
                    context: context,
                    context_len: context_len,
                    index: outPtr
                ), to: argsPtr
            )
            
            // - reset output
            try memory.copy(
                from: WAFuture(
                    data: 0,
                    len: 0,
                    callback: 0,
                    context: context,
                    context_len: context_len,
                    index: 0
                ), to: outPtr
            )
            
            debugPrint("[\(outPtr.hex)] callbacking \(argsPtr.hex)")
        } else {
            let f = WAFuture(
                data: offsetPtr,
                len: offsetLen,
                callback: 0,
                context: context,
                context_len: context_len,
                index: 0
            )
            try memory.copy(from: f, to: outPtr)
            
            debugPrint("[\(outPtr.hex)] updated out to \(f)")
        }
        
        return [argsPtr, offsetPtr]
    }
}

private extension Data {
    mutating func append(_ val: String) {
        if let data = val.data(using: .utf8) {
            append(data)
        }
    }
}

#if os(iOS)
import MobileCoreServices
#endif
extension String {
    func mimeType() -> String {
        let pathExtension = self
        if #available(macOS 11.0, iOS 15.0, watchOS 8.0, *) {
            if let type = UTType(filenameExtension: pathExtension) {
                if let mimetype = type.preferredMIMEType {
                    return mimetype as String
                }
            }
        } else {
#if os(iOS)
            if let uti = UTTypeCreatePreferredIdentifierForTag(
                kUTTagClassFilenameExtension,
                pathExtension as NSString, nil
            )?.takeRetainedValue() {
                if let mimetype = UTTypeCopyPreferredTagWithClass(uti, kUTTagClassMIMEType)?
                    .takeRetainedValue()
                {
                    return mimetype as String
                }
            }
#endif
        }
        return "application/octet-stream"
    }
}

extension URLSession {
    private func safe_data(for req: URLRequest) async -> (Data, URLResponse) {
        do {
            return try await data(for: req)
        } catch {
            return ("""
            {
                "error": "\(error.localizedDescription)"
            }
            """.data(using: .utf8) ?? Data(), URLResponse())
        }
    }
    
    func command(for req: URLRequest, id: String, usePtr: Bool = true, instance: Instance) async throws -> AsyncifyCommand {
        let (data, response) = await self.safe_data(for: req)
        var ret = AsyncifyCommand()
        ret.requestID = id
        ret.kind = .sync
        ret.sync = AsyncifyCommand.Sync()
        var http = AsyncifyCommand.Sync.HTTP()
        http.body = TypesBytes()
        if usePtr {
            var bptr = TypesPointer()
            bptr.len = UInt32(data.count)
            let allocator = instance.exports[function: "allocate"]!
            let memory = instance.exports[memory: "memory"]!
            // TODO: release ptr
            bptr.ptr = try memory.set(data: data, in: allocator)
            http.body.data = .ptr(bptr)
        } else {
            http.body.data = .raw(data)
        }
        
        if let response = response as? HTTPURLResponse,
           let allHeaderFields = response.allHeaderFields as? [String: String]
        {
            http.code = Int32(response.statusCode)
            for (k, v) in allHeaderFields {
                http.headers[k] = v
            }
            let cookies = HTTPCookie.cookies(
                withResponseHeaderFields: allHeaderFields, for: response.url!
            )
            for c in cookies {
                var ac = AsyncifyCookie()
                ac.name = c.name
                ac.value = c.value
                http.cookies.append(ac)
            }
        }
        ret.sync.action = .http(http)
        return ret
    }
}

extension AsyncifyAction.Regex {
    func command(for id: String, memory: Memory) throws -> AsyncifyCommand {
        var ret = AsyncifyCommand()
        ret.requestID = id
        ret.kind = .sync
        ret.sync = AsyncifyCommand.Sync()
        var regex = AsyncifyCommand.Sync.Regex()
        let pattern = NSRegularExpression(self.pattern)
        let str = input.toString(in: memory)
        if let matched = pattern.firstMatch(
            in: str,
            includingGroups: groups.map(Int.init)
        ) {
            regex.main = matched.0.toAsyncify(in: str)
            regex.groups = matched.1.reduce(
                [:])
            {
                var ret = $0
                ret[Int32($1.key)] = $1.value.toAsyncify(in: str)
                return ret
            }
        }
        ret.sync.action = .regex(regex)
        return ret
    }
}
extension AsyncifyAction.WebSocket {
    
    /// Send data to websocket
    /// - Parameters:
    ///   - id: request id
    ///   - instance: wasm instance
    /// - Returns: async command
    func command(for id: String, fnPtr: UInt32, instance: Instance) async throws -> AsyncifyCommand {
        let conn = try await WebSocketManager.shared.connect(req: req)
        conn.receive = { data in
            try self.sync(id: id, data: data, fnPtr: fnPtr, instance: instance)
        }
        var ret = AsyncifyCommand()
        ret.requestID = id
        ret.kind = .sync
        ret.sync = AsyncifyCommand.Sync()
        if self.hasBody {
            ret.sync.action = .ws(try await conn.send(data: self.body.bytes))
        } else {
            ret.sync.action = .ws(AsyncifyCommand.Sync.WebSocket())
        }
        return ret
    }
    
    func sync(id: String, data: Data?, fnPtr: UInt32, instance: Instance) throws {
        var ret = AsyncifyCommand()
        ret.requestID = id
        ret.kind = .sync
        ret.sync = AsyncifyCommand.Sync()
        
        let allocator = instance.exports[function: "allocate"]!
        let memory = instance.exports[memory: "memory"]!
        
        if let data {
            var ws = AsyncifyCommand.Sync.WebSocket()
            ws.body = TypesBytes()
            var bptr = TypesPointer()
            bptr.len = UInt32(data.count)
            // TODO: release ptr
            bptr.ptr = try memory.set(data: data, in: allocator)
            ws.body.ptr = bptr
            ret.sync.action = .ws(ws)
        }
        let callback = instance.exports[function: "callback"]!
        try Task.checkCancellation()
        let outPtr = try allocator([.i32(UInt32(MemoryLayout<WAFuture>.size))])[0].i32
        let offsetData = try ret.serializedData()
        let offsetPtr = try memory.set(data: offsetData, in: allocator)
        let offsetLen = UInt32(offsetData.count)
        let argsPtr = try allocator([.i32(UInt32(MemoryLayout<WAFuture>.size))])[0].i32
        try memory.copy(
            from: WAFuture(
                data: offsetPtr,
                len: offsetLen,
                callback: 0,
                context: 0,
                context_len: 0,
                index: outPtr
            ), to: argsPtr
        )
        try callback([.i32(outPtr), .i32(fnPtr), .i32(argsPtr)])
    }
    
    var req: URLRequest {
        var req = URLRequest(url: URL(string: self.url)!)
        for (k, v) in self.headers {
            req.setValue(v, forHTTPHeaderField: k)
        }
        return req
    }
}


extension AsyncifyAction.JavaScript {
    func command(for id: String) throws -> AsyncifyCommand {
#if canImport(JavaScriptCore)
        guard let context = JSContext() else {
            fatalError("failed to create JSContext")
        }
        context.evaluateScript(src)
        // TODO: cache context?
        
        var ret = AsyncifyCommand()
        ret.requestID = id
        ret.kind = .sync
        ret.sync = AsyncifyCommand.Sync()
        var eval = AsyncifyCommand.Sync.JavaScript()
        
        switch action {
        case let .eval(js):
            let function = context.objectForKeyedSubscript(js.fn)
            
            let result = function?.call(withArguments: js.args.js())
            // TODO: cache result
            
            if let result, result.isString {
                eval.eval = result.toString() ?? "null"
            }
            
            ret.sync.action = .js(eval)
            
        default:
            fatalError()
        }
        return ret
#else
        fatalError()
#endif
    }
}
enum AsyncifyActionError: Error {
    case invalidArgument(String)
}

extension AsyncifyAction.FileDescriptor {
    func command(for id: String) async throws -> AsyncifyCommand {
        var ret = AsyncifyCommand()
        ret.requestID = id
        ret.kind = .sync
        ret.sync = AsyncifyCommand.Sync()
        guard let file = URL(string: self.url) else {
            throw AsyncifyActionError.invalidArgument("url not valid")
        }
        var fd = AsyncifyCommand.Sync.FileDescriptor()
        switch action {
        case let .read(read):
            if read.hasEnc {
                throw AsyncifyActionError.invalidArgument("encoding not supported yet")
            }
            fd.status = 1
            fd.content = TypesBytes()
            fd.content.data = .raw(try Data(contentsOf: file))
        case .metadata:
            fd.status = 1
            fd.metadata = Google_Protobuf_Struct()
            let mime = file.pathExtension.mimeType()
            fd.metadata.fields["mime"] = Google_Protobuf_Value(stringValue: mime)
            let attributes = try FileManager.default.attributesOfItem(atPath: file.path)
            if let fileSize = attributes[.size] as? Double {
                fd.metadata.fields["file_size"] = Google_Protobuf_Value(numberValue: fileSize)
            }
            if let date = attributes[.creationDate] as? Date {
                fd.metadata.fields["created_at"] = Google_Protobuf_Value(numberValue: date.timeIntervalSince1970)
            }
            if let date = attributes[.modificationDate] as? Date {
                fd.metadata.fields["modified_at"] = Google_Protobuf_Value(numberValue: date.timeIntervalSince1970)
            }
            fd.metadata.fields["is_file"] = Google_Protobuf_Value(boolValue: file.isFileURL)
            fd.metadata.fields["is_dir"] = Google_Protobuf_Value(boolValue: !file.isFileURL)
            
            switch mime {
            case let x where x.hasPrefix("image/"):
#if canImport(CoreGraphics)
                if let provider = CGDataProvider(url: file as CFURL),
                   let source = CGImageSourceCreateWithDataProvider(provider, nil),
                   let metadata = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [AnyHashable: Any] {
                    if let width = metadata["PixelWidth"] as? CGFloat, let height = metadata["PixelHeight"] as? CGFloat {
                        fd.metadata.fields["resolution"] = Google_Protobuf_Value(listValue: Google_Protobuf_ListValue(values: [Google_Protobuf_Value(numberValue: width), Google_Protobuf_Value(numberValue: height)]))
                    }
                    
                }
#endif
            case let x where x.hasPrefix("video/") || x.hasPrefix("audio/"):
                let asset = AVURLAsset(url: file, options: [
                    AVURLAssetPreferPreciseDurationAndTimingKey: NSNumber(value: true)
                ])
                if let track = asset.tracks(withMediaType: .video).first {
                    let size = track.naturalSize.applying(track.preferredTransform)
                    fd.metadata.fields["resolution"] = Google_Protobuf_Value(listValue: Google_Protobuf_ListValue(values: [Google_Protobuf_Value(numberValue: size.width), Google_Protobuf_Value(numberValue: size.height)]))
                }
                if #available(macOS 12.0, iOS 15.0, watchOS 8.0, *) {
                    let duration = try await asset.load(.duration)
                    fd.metadata.fields["duration"] = Google_Protobuf_Value(numberValue: duration.seconds)
                } else {
                    fd.metadata.fields["duration"] = Google_Protobuf_Value(numberValue: asset.duration.seconds)
                }
            default: break
            }
        case let .write(write):
            switch write.enc {
            case "base64":
                try Data(base64Encoded: write.data.bytes)?.write(to: file)
            default:
                try write.data.bytes.write(to: file)
            }
        case .mkdir:
            if !FileManager.default.fileExists(atPath: file.path) {
                do {
                    try FileManager.default.createDirectory(at: file, withIntermediateDirectories: true)
                    fd.status = 1
                } catch {
                    fd.metadata = Google_Protobuf_Struct()
                    fd.metadata.fields["reason"] = Google_Protobuf_Value(stringValue: error.localizedDescription)
                }
            } else {
                fd.status = 1
            }
        case .delete:
            do {
                try FileManager.default.removeItem(at: file)
                fd.status = 1
            } catch {
                fd.metadata = Google_Protobuf_Struct()
                fd.metadata.fields["reason"] = Google_Protobuf_Value(stringValue: error.localizedDescription)
            }
        default:
            fatalError()
        }
        ret.sync.action = .fd(fd)
        return ret
    }
}
extension Sequence where Element == AsyncifyFieldEntry {
    func js() -> [Any] {
        reduce([]) {
            switch $1.type {
            case AsyncifyFieldEntry.TypeEnum.bool:
                return $0 + [Bool($1.value)]
            case AsyncifyFieldEntry.TypeEnum.int:
                return $0 + [Int($1.value)]
            case AsyncifyFieldEntry.TypeEnum.double:
                return $0 + [Double($1.value)]
            case AsyncifyFieldEntry.TypeEnum.string:
                return $0 + [$1.value]
            default:
                break
            }
            return $0
        }
        .compactMap { $0 }
    }
}

extension NSRegularExpression.Match {
    func toAsyncify(in str: String) -> AsyncifyCommand.Sync.Regex.Match {
        var ret = AsyncifyCommand.Sync.Regex.Match()
        let utf8Data = str.utf8
        ret.start = Int32(utf8Data.distance(from: utf8Data.startIndex, to: start))
        ret.end = Int32(utf8Data.distance(from: utf8Data.startIndex, to: end))
        return ret
    }
}

extension TypesString {
    func toString(in memory: Memory) -> String {
        switch data {
        case let .ptr(str):
            return memory.string(fromByteOffset: UInt32(str.ptr), len: Int(str.len)) ?? ""
        case let .raw(val):
            return val
        default:
            fatalError()
        }
    }
}

extension TypesBytes {
    var bytes: Data {
        switch data {
        case let .ptr(val):
            return Data(bytesNoCopy: UnsafeMutableRawPointer(bitPattern: Int(val.ptr))!,
                        count: Int(val.len),
                        deallocator: .none)
        case let .raw(val): return val
        default: fatalError()
        }
    }
}
