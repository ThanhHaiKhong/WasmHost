//
//  AsyncDownloader.swift
//  app
//
//  Created by L7Studio on 11/2/25.
//

import Foundation

extension AsyncDownloader {
    public enum Event {
        case progress(currentBytes: Int64, totalBytes: Int64)
        case success(url: URL)
    }
}
class AsyncDownloader: NSObject {
    let url: URL
    let destination: URL
    fileprivate var continuation: AsyncThrowingStream<Event, Error>.Continuation?
    
    fileprivate lazy var task: URLSessionDownloadTask = {
        var req = URLRequest(url: url)
        // to fix content-length
        req.setValue("", forHTTPHeaderField: "Accept-Encoding")
        let task = AsyncDownloaderSession.shared.sessionManager.downloadTask(with: req)
        return task
    }()
    
    init(url: URL, destination: URL) {
        self.url = url
        self.destination = destination
    }
    
    public var isDownloading: Bool {
        task.state == .running
    }
    
    public var events: AsyncThrowingStream<Event, Error> {
        AsyncThrowingStream { continuation in
            self.continuation = continuation
            task.resume()
            continuation.onTermination = { @Sendable [weak self] _ in
                self?.task.cancel()
            }
        }
    }
    
    func pause() {
        task.suspend()
    }
    
    func resume() {
        task.resume()
    }
}

final class AsyncDownloaderSession: NSObject, URLSessionDownloadDelegate {
    public static let shared = AsyncDownloaderSession()
    let sessionIdentifier = "\(Bundle.main.bundleIdentifier!).AsyncDownloaderSession"
    var items: [Int: AsyncDownloader] = [:]
    lazy var sessionManager: URLSession = {
        let configuration = URLSessionConfiguration.background(withIdentifier: sessionIdentifier)
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = nil
        return URLSession(configuration: configuration, delegate: self, delegateQueue: .main)
    }()
    
    func download(url: URL, destination: URL) -> AsyncDownloader {
        let downloader = AsyncDownloader(url: url, destination: destination)
        self.items[downloader.task.taskIdentifier] = downloader
        return downloader
    }
}

extension AsyncDownloaderSession {
    
    fileprivate func downloadTasks() -> [URLSessionDownloadTask] {
        var tasks: [URLSessionDownloadTask] = []
        let semaphore : DispatchSemaphore = DispatchSemaphore(value: 0)
        sessionManager.getTasksWithCompletionHandler { (dataTasks, uploadTasks, downloadTasks) -> Void in
            tasks = downloadTasks
            semaphore.signal()
        }
        
        let _ = semaphore.wait(timeout: DispatchTime.distantFuture)
        
        debugPrint("AsyncDownloaderSession: pending tasks \(tasks)")
        
        return tasks
    }

    func urlSession(_ session: URLSession,
                           downloadTask: URLSessionDownloadTask,
                           didWriteData bytesWritten: Int64,
                           totalBytesWritten: Int64,
                           totalBytesExpectedToWrite: Int64) {
        guard let continuation =  items[downloadTask.taskIdentifier]?.continuation else {
            return
        }
        continuation.yield(
            .progress(
                currentBytes: totalBytesWritten,
                totalBytes: totalBytesExpectedToWrite))
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let downloader = items[downloadTask.taskIdentifier] else {
            return
        }
        guard let continuation = downloader.continuation else {
            return
        }
        
        let fileManager = FileManager.default
        
        let basePath = downloader.destination.deletingLastPathComponent()
        
        if !fileManager.fileExists(atPath: basePath.absoluteString) {
            do {
                try fileManager.createDirectory(atPath: basePath.path, withIntermediateDirectories: true, attributes: nil)
            } catch {
                continuation.finish(throwing: error)
            }
        }
        if !fileManager.fileExists(atPath: downloader.destination.path) {
            do {
                try fileManager.moveItem(at: location, to: downloader.destination)
                continuation.yield(.success(url: downloader.destination))
                continuation.finish()
            } catch {
                continuation.finish(throwing: error)
            }
        } else {
            continuation.yield(.success(url: downloader.destination))
            continuation.finish()
        }
       
    }
    
    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        debugPrint("All tasks are finished")
    }
}

