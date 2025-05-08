//
//  Player.swift
//  app
//
//  Created by L7Studio on 4/2/25.
//
import AsyncWasm
import SwiftUI
import AsyncWasmUI
import MusicWasm
import WasmSwiftProtobuf
import AVKit
import OSLog
#if canImport(VLC)
import VLC
#endif

@Observable
class Player: NSObject {
    @ObservationIgnored var engine = try! WasmEngine<MusicWasmEngine>()
#if canImport(VLC)
    @ObservationIgnored private lazy var player: VLCMediaPlayer = {
        let ret = VLCMediaPlayer()
        ret.delegate = self
        return ret
    }()
#else
    @ObservationIgnored private lazy var player: AVPlayer = {
        let ret = AVPlayer(playerItem: nil)
        ret.automaticallyWaitsToMinimizeStalling = false
        return ret
    }()
#endif
    var bookmarks = try! BookmarksTrack()
    var duration: TimeInterval = 0.0
    var currentTime: TimeInterval = 0.0
    @ObservationIgnored private var trackTask: Task<Void, Swift.Error>?
    var track: WasmSwiftProtobuf.MusicTrack? { didSet {
        let isChanged = self.track?.id != oldValue?.id
        if isChanged {
            self.stop()
            state = .buffering
            trackTask?.cancel()
        }
        
        if case let .buffering = self.state {
            if trackTask?.isCancelled ==  false { return }
            trackTask = Task.detached {
                if let track = self.track {
                    try await self.load(track: track)
                }
            }
        }
    }}
    enum State {
        case none, buffering, playing, paused, stopped, failed(Swift.Error)
    }
    enum Error: Swift.Error {
        case notFound
    }
    var state = State.none
    @ObservationIgnored private var current: WasmSwiftProtobuf.MusicTrackDetails? {
        didSet {
            self.removePeriodicTimeObserver()
            if self.current == nil {
                self.player.pause()
#if canImport(VLC)
                self.player.media = nil
#else
                self.player.replaceCurrentItem(with: nil)
#endif
                return
            }
            let isChanged = self.current?.id != oldValue?.id
            if !isChanged {
                self.toggle()
                return
            }
            guard let audio = self.current?.formats.first(where: { $0.mimeType.contains("audio") }) else {
                self.state = .failed(Error.notFound)
                return
            }
            
            WALogger.host.debug("[\(self.current!.id)] found audio \(try! audio.jsonString())")
            guard let url = URL(string: audio.url) else { return }
            state = .buffering
            Task {
                defer {
                    self.addPeriodicTimeObserver()
                }
                self.progress = 0
#if canImport(VLC)
                player.media = VLCMedia(url: url)
                self.duration = Double(player.media?.length.intValue ?? 0) / 1000
                player.play()
#else
                let asset = AVAsset(url: url)
                let values = try await asset.load(.isPlayable, .duration)
                self.duration = values.1.seconds
                await player.replaceCurrentItem(with: AVPlayerItem(asset: asset, automaticallyLoadedAssetKeys: nil))
                player.playImmediately(atRate: 1.0)
                state = .playing
#endif
            }
            
        }
    }
    
    private var timeObserver: Any?
    var progress: Float = 0
    @ViewBuilder
    func indicatorView() -> some View {
        switch self.state {
        case .buffering:
            ProgressView()
        case .playing:
            Image(systemName: "pause")
        case .paused:
            Image(systemName: "play")
        case .failed:
            Image(systemName: "exclamationmark.triangle")
        default:
            EmptyView()
        }
    }
    init(progress: Float = 0, track: WasmSwiftProtobuf.MusicTrack? = nil) {
        self.progress = progress
        self.track = track
    }
    
    deinit {
        self.removePeriodicTimeObserver()
    }
    
    private func stop() {
        self.progress = 0
        self.currentTime = 0
        self.duration = 0
        self.current = nil
    }
    
    /// Adds an observer of the player timing.
    private func addPeriodicTimeObserver() {
        // Create a 0.5 second interval time.
        let interval = CMTime(value: 1, timescale: 2)
#if !canImport(VLC)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval,
                                                      queue: .main) { [weak self] time in
            guard let self else { return }
            // Update the published currentTime and duration values.
            currentTime = time.seconds
            duration = player.currentItem?.duration.seconds ?? 0.0
            progress = Float(currentTime / duration)
            if self.player.rate > 0 {
                self.state = .playing
            } else {
                self.state = .paused
            }
        }
#endif
    }

    func toggle() {
        self.player.isPlaying ? self.player.pause() : self.player.play()
    }
    /// Removes the time observer from the player.
    private func removePeriodicTimeObserver() {
        guard let timeObserver else { return }
#if canImport(VLC)
        (self.timeObserver as? Timer)?.invalidate()
#else
        player.removeTimeObserver(timeObserver)
#endif
        
        self.timeObserver = nil
    }
    
    private func load(track: WasmSwiftProtobuf.MusicTrack, version: WasmSwiftProtobuf.EngineVersion? = nil) async throws {
        let details: MusicTrackDetails = try await self.engine.instance.details(vid: track.id)
        await MainActor.run {
            self.current = details
        }
    }
}
#if canImport(VLC)
extension Player: VLCMediaPlayerDelegate {
    
    func mediaPlayerTimeChanged(_ aNotification: Notification) {
        guard let player = aNotification.object as? VLCMediaPlayer else { return }
        currentTime = Double(player.time.intValue) / 1000
        duration =  Double(player.media?.length.intValue ?? 0) / 1000
        progress = player.position
        state = player.isPlaying ? .playing : .paused
    }
    func mediaPlayerStateChanged(_ aNotification: Notification) {
        guard let player = aNotification.object as? VLCMediaPlayer else { return }
        switch player.state {
        case .playing: self.state = .playing
        case .stopped: self.state = .stopped
        case .buffering: self.state = .buffering
        case .paused: self.state = .paused
        case .ended:
            self.state = .paused
            self.progress = 0
            self.currentTime = 0
//        case .error: self.state = .failed(<#T##any Error#>)
        default:
            break
        }
    }
}
#endif
