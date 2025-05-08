//
//  AsyncWasmTests.swift
//  WasmHost
//
//  Created by L7Studio on 23/12/24.
//
import Foundation
import XCTest
@testable import AsyncWasm

final class AsyncWasmTests: XCTestCase {
    var sut: AsyncWasmProtocol!
    override func setUp() async throws {
        try await super.setUp()
        self.sut = try AsyncWasmEngine(
            file: Bundle.module.url(forResource: "music_tube", withExtension: "wasm")!)
    }
    func testGetVersion() async throws {
        print(try await sut.version().jsonString())
    }
}
