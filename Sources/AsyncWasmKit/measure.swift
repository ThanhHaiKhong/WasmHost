//
//  measure.swift
//  WasmHost
//
//  Created by L7Studio on 17/2/25.
//


@discardableResult
func measure<R>(msg: String = "", functionName: String = #function, body: () throws -> R) rethrows -> R {
    #if DEBUG_MEASURE // Don't waste time logging unless we're in debug
        // I'm using CoreFoundation's clock as an example,
        // but you can use `clock_gettime(CLOCK_MONOTONIC, ...)` or whatever
        let startTime = CFAbsoluteTimeGetCurrent()

        defer {
            let endTime = CFAbsoluteTimeGetCurrent()
            let duration = endTime - startTime
            NSLog("\(msg) \(functionName): \(duration) seconds")
        }
    #endif
    return try body()
}
