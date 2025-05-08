//
//  ext.swift
//  WasmHost
//
//  Created by L7Studio on 18/2/25.
//
import Foundation
import WasmSwiftProtobuf

extension EngineCallID: CallerID {}

public func backoff(attempts: Int) -> TimeInterval {
    if attempts > 13 {
        return 2 * 60
    }
    let delay = pow(Double(attempts), M_E) * 0.1
    return delay
}

extension String {
    var boolValue: Bool? {
        switch self.lowercased() {
        case "true", "yes", "1": return true
        case "false", "no", "0": return false
        default: return nil // Invalid boolean string
        }
    }
}
