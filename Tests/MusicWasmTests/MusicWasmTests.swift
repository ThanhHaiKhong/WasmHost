//
//  AsyncWasmTests.swift
//  WasmHost
//
//  Created by L7Studio on 23/12/24.
//
import Foundation
import XCTest
@testable import MusicWasm
@testable import AsyncWasm
import WasmSwiftProtobuf

final class AsyncWasmTests: XCTestCase {
    var sut: MusicWasmProtocol!
    override func setUp() async throws {
        try await super.setUp()
        self.sut = try MusicWasmEngine(
            file: Bundle.module.url(forResource: "music_tube", withExtension: "wasm")!)
        try await self.sut.start()
    }
    
    func testGetDetails() async throws {
        // age restricted HtVdAasjOgU
        //        let vid = "NgDl-a8Wq7w"
        //        let vid = "vJO_3BSrXWk" // ytdlp sometime require signin
        // yt-dlp --extractor-args "youtube:player_client=ios" -f 139 vJO_3BSrXWk --get-url
        self.measureMetrics([.wallClockTime], automaticallyStartMeasuring: true) {
            let exp = expectation(description: "Finished")
            Task {
                let vid = "kPa7bsKwL-c"
                let details = try await sut.details(vid: vid)
                XCTAssertEqual(details.id, vid)
                XCTAssertGreaterThan(details.formats.count, 0)
                exp.fulfill()
            }
            wait(for: [exp], timeout: 60.0)
        }
    }
    func testSearch() async throws {
        print(try await sut.search(keyword: "i know your ways", scope: MusicSearchScope.all, continuation: nil).jsonString())
    }
    func testSearchEmptyKeyword() async throws {
        print(try await sut.search(keyword: "", scope: MusicSearchScope.all, continuation: nil).jsonString())
    }
    @available(iOS 16.0, *)
    func testGenPreviewData() async throws {
        let out = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appending(component: "Sources/MusicWasm/Resources")
        
        try await sut.details(vid: "kPa7bsKwL-c").serializedData().write(to: out.appending(component: "details.dat"))
        try await sut.search(keyword: "die with a smile", scope: MusicSearchScope.all, continuation: nil).serializedData().write(to: out.appending(component: "search.dat"))
    }
    func testCallID() throws {
        XCTAssertEqual(try EngineCallID.getVersion.to_asyncify_call_id(), "ENGINE_CALL_ID_GET_VERSION")
        enum Foo: CallerID {
            case bar
            case bar2
            case bar_3
            case fooBar
        }
        
        XCTAssertEqual(try Foo.bar.to_asyncify_call_id(), "FOO_BAR")
        XCTAssertEqual(try Foo.bar2.to_asyncify_call_id(), "FOO_BAR2")
        XCTAssertEqual(try Foo.bar_3.to_asyncify_call_id(), "FOO_BAR_3")
        XCTAssertEqual(try Foo.fooBar.to_asyncify_call_id(), "FOO_FOO_BAR")
        
        enum FooPrefix: CallerID {
            case bar
            func prefix() -> String? {
                "BAR"
            }
        }
        
        XCTAssertEqual(try FooPrefix.bar.to_asyncify_call_id(), "BAR_BAR")
    }
}
