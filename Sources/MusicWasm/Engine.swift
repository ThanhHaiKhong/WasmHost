//
//  Engine.swift
//  WasmHost
//
//  Created by L7Studio on 17/1/25.
//
import AsyncWasm
import Foundation
import SwiftProtobuf
import WasmSwiftProtobuf
import TaskWasm

public enum MusicActionID: String, CaseIterable, Identifiable {
    public var id: String { self.rawValue }
    case suggestion = "c5edf8f6-e18d-4a9d-acef-27d19fbb909a"
    case discover = "0e425df1-fcda-4489-969a-d4350392a016"
    case details = "1b1bcaf6-01fc-40b4-83b8-36915d9e505c"
    case tracks = "a9b31651-43b3-415a-b99c-00468be15e28"
    case search = "5d922423-a6fb-4302-b951-ac074c681b7c"
    case transcript = "47575b25-3d87-4c9d-96d5-a681d064884b"
}

public enum MusicDiscoverCategory: String, CaseIterable, Identifiable {
    public var id: String { self.rawValue }
    case trending = "a63edea2-0dea-4ff6-a473-aaaa40532d08"
    case recommended = "46805b5e-681e-481f-af2f-4cd0d3463e9b"
    case news = "029aeecf-fad6-4134-bb60-9fea34381dce"
}
public enum MusicSearchScope: String, CaseIterable, Identifiable {
    public var id: String { self.rawValue }
    case all = "all"
    case playlist = "playlist"
    case video = "video"
}

public protocol MusicWasmProtocol: TaskWasmProtocol {
    func details(vid: String) async throws -> MusicTrackDetails
    func suggestion(keyword: String) async throws -> MusicListSuggestions
    func search(keyword: String, scope: MusicSearchScope, continuation: String?) async throws -> MusicListTracks
    func tracks(pid: String, continuation: String?) async throws -> MusicListTracks
    func discover(category: MusicDiscoverCategory, continuation: String?) async throws -> MusicListTracks
}

public func `default`() async throws -> MusicWasmProtocol {
    MusicWasmEngine()
}

public extension MusicWasmEngine {
    internal static let kMaxRetryCount = 10

    func details(vid: String) async throws -> MusicTrackDetails {
        var attempts = 0

        while attempts < Self.kMaxRetryCount {
            attempts += 1
            let val: MusicTrackDetails = try await cast(await details(vid: vid))
            if val.formats.isEmpty {
                WALogger.host.debug("[\(vid)] \(attempts) retrying...")
                try await Task.sleep(nanoseconds: UInt64(backoff(attempts: attempts) * 1_000_000_000))
                continue
            }
            if let url = val.formats.first?.url, let url = URL(string: url) {
                var req = URLRequest(url: url)
                req.httpMethod = "HEAD"
                let resp = try await URLSession.shared.data(for: req)
                let status = (resp.1 as? HTTPURLResponse)?.statusCode ?? -1
                if status == 200 {
                    return val
                }
            }
        }
        throw Constants.Error.maximumRetryExceededError.error()
    }

    func transcript(vid: String) async throws -> MusicTranscript {
        try await cast(await transcript(vid: vid))
    }

    func discover(category: MusicDiscoverCategory, continuation: String?) async throws -> MusicListTracks {
        try await cast(await discover(category: category.rawValue, continuation: continuation))
    }

    func suggestion(keyword: String) async throws -> MusicListSuggestions {
        try await cast(await suggestion(keyword: keyword))
    }

    func search(keyword: String, scope: MusicSearchScope, continuation: String?) async throws -> MusicListTracks {
        try await cast(await search(keyword: keyword, scope: scope.rawValue, continuation: continuation))
    }

    func tracks(pid: String, continuation: String?) async throws -> MusicListTracks {
        try await cast(await tracks(pid: pid, continuation: continuation))
    }
}

@objc
public class MusicWasmEngine: TaskWasmEngine, MusicWasmProtocol {

    @objc(detailsWithVideoId:completionHandler:)
    public func details(vid: String) async throws -> Data {
        try await self.data(id: MusicActionID.details, args: [
            "url": Google_Protobuf_Value(stringValue: vid),
        ])
    }

    @objc(transcriptWithVideoId:completionHandler:)
    public func transcript(vid: String) async throws -> Data {
        try await self.data(id: MusicActionID.transcript, args: [
            "url": Google_Protobuf_Value(stringValue: vid),
        ])
    }

    @objc(getDiscoverWithCategory:continuation:completionHandler:)
    public func discover(category: String, continuation: String?) async throws -> Data {
        var args = [
            "category": Google_Protobuf_Value(stringValue: category),
        ]
        if let continuation, !continuation.isEmpty {
            args["continuation"] = Google_Protobuf_Value(stringValue: continuation)
        }
        return try await self.data(id: MusicActionID.discover, args: args)
    }

    @objc(suggestionWithKeyword:completionHandler:)
    public func suggestion(keyword: String) async throws -> Data {
        let args = [
            "keyword": Google_Protobuf_Value(stringValue: keyword),
        ]
        return try await self.data(id: MusicActionID.suggestion, args: args)
    }

    @objc(searchWithKeyword:scope:continuation:completionHandler:)
    public func search(keyword: String, scope: String, continuation: String?) async throws -> Data {
        var args = [
            "keyword": Google_Protobuf_Value(stringValue: keyword),
            "scope": Google_Protobuf_Value(stringValue: scope),
        ]
        if let continuation, !continuation.isEmpty {
            args["continuation"] = Google_Protobuf_Value(stringValue: continuation)
        }
        return try await self.data(id: MusicActionID.search, args: args)
    }

    @objc(trackWithPlaylistId:continuation:completionHandler:)
    public func tracks(pid: String, continuation: String?) async throws -> Data {
        var args = [
            "id": Google_Protobuf_Value(stringValue: pid),
        ]
        if let continuation {
            args["continuation"] = Google_Protobuf_Value(stringValue: continuation)
        }
        return try await self.data(id: MusicActionID.tracks, args: args)
    }
}
