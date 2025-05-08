//
//  caller.swift
//  WasmHost
//
//  Created by L7Studio on 9/1/25.
//
import Foundation
import SwiftProtobuf
import WasmSwiftProtobuf
#if canImport(UIKit)
import UIKit
#endif
#if os(watchOS)
import WatchKit
#endif
public protocol CallerID {
    func prefix() -> String?
}
extension CallerID {
    public func prefix() -> String? {
        return nil
    }
}

extension CallerID {
    func to_asyncify_call_id() throws -> String {
        let elms = String(reflecting: self).components(separatedBy: ".")
        if let prefix = self.prefix() {
            return try [prefix, elms.last!].map({ try $0.snakecased().uppercased() }).joined(separator: "_")
        }
        return try elms.dropFirst(elms.count - 2)
            .map({ try $0.snakecased().uppercased() }).joined(separator: "_")
    }
    
}
extension String {
    func snakecased() throws -> String {
        let pattern = "([a-z])([A-Z])"
        let regex = try NSRegularExpression(pattern: pattern, options: [])
        let range = NSRange(location: 0, length: self.utf16.count)
        let result = regex.stringByReplacingMatches(in: self, options: [], range: range, withTemplate: "$1_$2")
        return result.lowercased()
    }
}

extension AsyncifyCommand.Call {
    public init(id: String, args: [String: Google_Protobuf_Value] = [:]) {
        self.init()
        self.id = id
        self.args = Google_Protobuf_Struct(fields: args)
    }
    public init(id: CallerID, args: [String: Google_Protobuf_Value] = [:]) throws {
        self.init()
        self.id = try id.to_asyncify_call_id()
        self.args = Google_Protobuf_Struct(fields: args)
    }
}
extension AsyncifyCommand {
    public init(call: Call) {
        self.init()
        self.requestID = UUID().uuidString
        self.kind = .call
        self.call = call
        self.options = AsyncifyOptions.default()
    }
}
extension AsyncifyOptions {
    static func `default`() -> Self {
        var val = AsyncifyOptions()
        val.contentType = "application/json"
        val.bundleID = Bundle.main.bundleIdentifier ?? ""
#if os(iOS) && canImport(UIKit)
        val.deviceID = UIDevice.current.identifierForVendor?.uuidString ?? ""
        val.platform = "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)"
#elseif os(watchOS)
        val.deviceID = WKInterfaceDevice.current().identifierForVendor?.uuidString ?? ""
        val.platform = "watchOS \(WKInterfaceDevice.current().systemVersion)"
#endif
        val.countryCode = Locale.current.identifier
        val.languageCode = Locale.current.languageCode ?? "en"
        val.regionCode = Locale.current.regionCode ?? "US"
        val.appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ("Unknown")
        return val
    }
}
