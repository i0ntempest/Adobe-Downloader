//
//  Adobe Downloader
//
//  Created by X1a0He on 2025/07/13.
//

import Foundation

struct DownloadChunk {
    let index: Int
    let startOffset: Int64
    let endOffset: Int64
    let size: Int64
    var downloadedSize: Int64 = 0
    var isCompleted: Bool = false
    var isPaused: Bool = false
    
    var progress: Double {
        return size > 0 ? Double(downloadedSize) / Double(size) : 0.0
    }
}

struct ChunkedDownloadState: Codable {
    let packageIdentifier: String
    let totalSize: Int64
    let chunkSize: Int64
    let chunks: [ChunkInfo]
    let totalDownloadedSize: Int64
    let isCompleted: Bool
    let destinationURL: String
    
    struct ChunkInfo: Codable {
        let index: Int
        let startOffset: Int64
        let endOffset: Int64
        let size: Int64
        let downloadedSize: Int64
        let isCompleted: Bool
        let isPaused: Bool
    }
}

class ChunkedDownloadManager {
    static let shared = ChunkedDownloadManager()

    private var chunkSize: Int64 {
        return Int64(StorageData.shared.chunkSizeMB) * 1024 * 1024 // 转换为字节
    }
    
    private let fileManager = FileManager.default
    private var stateDirectory: URL

    private var maxConcurrentChunks: Int {
        return StorageData.shared.maxConcurrentDownloads
    }

    private var activeTasks: [String: Task<Void, Error>] = [:]
    private let taskLock = NSLock()
    
    private init() {
        let containerURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        stateDirectory = containerURL.appendingPathComponent("Adobe Downloader/chunkStates", isDirectory: true)
        try? fileManager.createDirectory(at: stateDirectory, withIntermediateDirectories: true)
    }

    func checkRangeSupport(url: URL, headers: [String: String] = [:]) async throws -> (supportsRange: Bool, totalSize: Int64, etag: String?) {
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.httpError(httpResponse.statusCode, "HEAD request failed")
        }
        
        let acceptsRanges = httpResponse.value(forHTTPHeaderField: "Accept-Ranges")?.lowercased() == "bytes"
        let contentLength = Int64(httpResponse.value(forHTTPHeaderField: "Content-Length") ?? "0") ?? 0
        let etag = httpResponse.value(forHTTPHeaderField: "ETag")

        return (acceptsRanges, contentLength, etag)
    }

    func createChunkedDownload(packageIdentifier: String, totalSize: Int64, destinationURL: URL) -> [DownloadChunk] {
        let numChunks = Int(ceil(Double(totalSize) / Double(chunkSize)))
        var chunks: [DownloadChunk] = []
        
        for i in 0..<numChunks {
            let startOffset = Int64(i) * chunkSize
            let endOffset = min(startOffset + chunkSize - 1, totalSize - 1)
            let size = endOffset - startOffset + 1
            
            chunks.append(DownloadChunk(
                index: i,
                startOffset: startOffset,
                endOffset: endOffset,
                size: size
            ))
        }

        return chunks
    }

    private func writeDataToFile(data: Data, destinationURL: URL, offset: Int64) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                do {
                    let directory = destinationURL.deletingLastPathComponent()
                    if !self.fileManager.fileExists(atPath: directory.path) {
                        try self.fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
                    }

                    if !self.fileManager.fileExists(atPath: destinationURL.path) {
                        let success = self.fileManager.createFile(atPath: destinationURL.path, contents: nil)
                        if !success {
                            throw NetworkError.filePermissionDenied(destinationURL.path)
                        }
                    }

                    let fileHandle = try FileHandle(forWritingTo: destinationURL)
                    defer { fileHandle.closeFile() }
                    
                    fileHandle.seek(toFileOffset: UInt64(offset))
                    fileHandle.write(data)
                    
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func downloadChunkToFile(
        chunk: DownloadChunk,
        url: URL,
        destinationURL: URL,
        headers: [String: String] = [:],
        progressHandler: ((Int64, Int64) -> Void)? = nil,
        cancellationHandler: (() async -> Bool)? = nil
    ) async throws -> DownloadChunk {
        
        var modifiedChunk = chunk

        if let cancellationHandler = cancellationHandler {
            if await cancellationHandler() {
                modifiedChunk.isPaused = true
                throw NetworkError.cancelled
            }
        }

        if fileManager.fileExists(atPath: destinationURL.path) {
            let existingSize = (try? fileManager.attributesOfItem(atPath: destinationURL.path)[.size] as? Int64) ?? 0

            if existingSize > chunk.endOffset {
                modifiedChunk.downloadedSize = chunk.size
                modifiedChunk.isCompleted = true
                return modifiedChunk
            }

            let chunkActualStartOffset = chunk.startOffset + chunk.downloadedSize
            if existingSize > chunkActualStartOffset {
                let alreadyDownloaded = min(existingSize - chunkActualStartOffset, chunk.size - chunk.downloadedSize)
                modifiedChunk.downloadedSize += alreadyDownloaded
            }
        }

        if modifiedChunk.downloadedSize >= chunk.size {
            modifiedChunk.isCompleted = true
            return modifiedChunk
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 300
        
        let actualStartOffset = chunk.startOffset + modifiedChunk.downloadedSize
        request.setValue("bytes=\(actualStartOffset)-\(chunk.endOffset)", forHTTPHeaderField: "Range")
        headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }


        return try await withTaskCancellationHandler {
            modifiedChunk.isPaused = true
        } operation: {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            try Task.checkCancellation()
            if let cancellationHandler = cancellationHandler {
                if await cancellationHandler() {
                    modifiedChunk.isPaused = true
                    throw NetworkError.cancelled
                }
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }
            
            if httpResponse.statusCode == 206 || httpResponse.statusCode == 200 {
                try await writeDataToFile(data: data, destinationURL: destinationURL, offset: actualStartOffset)
                
                modifiedChunk.downloadedSize += Int64(data.count)
                
                if modifiedChunk.downloadedSize >= chunk.size {
                    modifiedChunk.isCompleted = true
                }
                
                progressHandler?(modifiedChunk.downloadedSize, chunk.size)
                
            } else {
                throw NetworkError.httpError(httpResponse.statusCode, "分片下载失败")
            }
            
            return modifiedChunk
        }
    }

    func pauseDownload(packageIdentifier: String) {
        taskLock.lock()
        defer { taskLock.unlock() }
        
        if let task = activeTasks[packageIdentifier] {
            task.cancel()
            activeTasks.removeValue(forKey: packageIdentifier)
        }
    }

    func cancelDownload(packageIdentifier: String) {
        taskLock.lock()
        defer { taskLock.unlock() }
        
        if let task = activeTasks[packageIdentifier] {
            task.cancel()
            activeTasks.removeValue(forKey: packageIdentifier)
        }
        
        clearChunkedDownloadState(packageIdentifier: packageIdentifier)
    }

    func saveChunkedDownloadState(packageIdentifier: String, chunks: [DownloadChunk], totalSize: Int64, destinationURL: URL) {
        let chunkInfos = chunks.map { chunk in
            ChunkedDownloadState.ChunkInfo(
                index: chunk.index,
                startOffset: chunk.startOffset,
                endOffset: chunk.endOffset,
                size: chunk.size,
                downloadedSize: chunk.downloadedSize,
                isCompleted: chunk.isCompleted,
                isPaused: chunk.isPaused
            )
        }
        
        let state = ChunkedDownloadState(
            packageIdentifier: packageIdentifier,
            totalSize: totalSize,
            chunkSize: self.chunkSize,
            chunks: chunkInfos,
            totalDownloadedSize: chunks.reduce(0) { $0 + $1.downloadedSize },
            isCompleted: chunks.allSatisfy { $0.isCompleted },
            destinationURL: destinationURL.path
        )
        
        let fileName = "\(packageIdentifier.replacingOccurrences(of: "/", with: "_")).chunkstate"
        let fileURL = stateDirectory.appendingPathComponent(fileName)
        
        do {
            let data = try JSONEncoder().encode(state)
            try data.write(to: fileURL)
        } catch {
        }
    }
    
    func loadChunkedDownloadState(packageIdentifier: String) -> ChunkedDownloadState? {
        let fileName = "\(packageIdentifier.replacingOccurrences(of: "/", with: "_")).chunkstate"
        let fileURL = stateDirectory.appendingPathComponent(fileName)
        
        do {
            let data = try Data(contentsOf: fileURL)
            let state = try JSONDecoder().decode(ChunkedDownloadState.self, from: data)
            return state
        } catch {
            return nil
        }
    }
    
    func restoreChunksFromState(_ state: ChunkedDownloadState) -> [DownloadChunk] {
        return state.chunks.map { chunkInfo in
            DownloadChunk(
                index: chunkInfo.index,
                startOffset: chunkInfo.startOffset,
                endOffset: chunkInfo.endOffset,
                size: chunkInfo.size,
                downloadedSize: chunkInfo.downloadedSize,
                isCompleted: chunkInfo.isCompleted,
                isPaused: chunkInfo.isPaused
            )
        }
    }
    
    func clearChunkedDownloadState(packageIdentifier: String) {
        let fileName = "\(packageIdentifier.replacingOccurrences(of: "/", with: "_")).chunkstate"
        let fileURL = stateDirectory.appendingPathComponent(fileName)
        try? fileManager.removeItem(at: fileURL)
    }

    func downloadFileWithChunks(
        packageIdentifier: String,
        url: URL,
        destinationURL: URL,
        headers: [String: String] = [:],
        progressHandler: ((Double, Int64, Int64, Double) -> Void)? = nil,
        cancellationHandler: (() async -> Bool)? = nil
    ) async throws {
        let downloadTask = Task<Void, Error> {
            let (supportsRange, totalSize, etag) = try await checkRangeSupport(url: url, headers: headers)
            
            guard totalSize > 0 else {
                throw NetworkError.invalidData("无法获取文件大小")
            }

            var chunks: [DownloadChunk]
            if let savedState = loadChunkedDownloadState(packageIdentifier: packageIdentifier) {
                if savedState.totalSize == totalSize,
                   savedState.destinationURL == destinationURL.path,
                   savedState.packageIdentifier == packageIdentifier,
                   savedState.chunkSize == self.chunkSize {
                    chunks = restoreChunksFromState(savedState).map { chunk in
                        var restoredChunk = chunk
                        restoredChunk.isPaused = false
                        return restoredChunk
                    }
                } else {
                    clearChunkedDownloadState(packageIdentifier: packageIdentifier)

                    if supportsRange && totalSize > chunkSize {
                        chunks = createChunkedDownload(
                            packageIdentifier: packageIdentifier,
                            totalSize: totalSize,
                            destinationURL: destinationURL
                        )
                    } else {
                        chunks = [DownloadChunk(
                            index: 0,
                            startOffset: 0,
                            endOffset: totalSize - 1,
                            size: totalSize
                        )]
                    }
                }
            } else {
                if supportsRange && totalSize > chunkSize {
                    chunks = createChunkedDownload(
                        packageIdentifier: packageIdentifier,
                        totalSize: totalSize,
                        destinationURL: destinationURL
                    )
                } else {
                    chunks = [DownloadChunk(
                        index: 0,
                        startOffset: 0,
                        endOffset: totalSize - 1,
                        size: totalSize
                    )]
                }
            }

            let incompleteChunks = chunks.filter { !$0.isCompleted && !$0.isPaused }
            if incompleteChunks.isEmpty {
                return
            }
            
            let chunkConcurrency = min(maxConcurrentChunks, 5)

            actor SpeedTracker {
                private var lastProgressTime = Date()
                private var lastDownloadedSize: Int64 = 0
                
                func updateSpeed(currentDownloaded: Int64) -> Double {
                    let now = Date()
                    let timeDiff = now.timeIntervalSince(lastProgressTime)
                    
                    if timeDiff >= 0.5 {
                        let sizeDiff = currentDownloaded - lastDownloadedSize
                        let speed = timeDiff > 0 ? Double(sizeDiff) / timeDiff : 0
                        
                        lastProgressTime = now
                        lastDownloadedSize = currentDownloaded
                        
                        return speed
                    }
                    return 0
                }
                
                func initialize(initialSize: Int64) {
                    lastDownloadedSize = initialSize
                    lastProgressTime = Date()
                }
            }

            actor ChunkStateManager {
                private var chunks: [DownloadChunk]
                
                init(chunks: [DownloadChunk]) {
                    self.chunks = chunks
                }
                
                func updateChunkProgress(index: Int, downloadedSize: Int64, isCompleted: Bool = false) {
                    if let chunkIndex = chunks.firstIndex(where: { $0.index == index }) {
                        chunks[chunkIndex].downloadedSize = downloadedSize
                        if isCompleted {
                            chunks[chunkIndex].isCompleted = true
                        }
                    }
                }
                
                func updateChunk(_ updatedChunk: DownloadChunk) {
                    if let index = chunks.firstIndex(where: { $0.index == updatedChunk.index }) {
                        chunks[index] = updatedChunk
                    }
                }
                
                func getAllChunks() -> [DownloadChunk] {
                    return chunks
                }
                
                func getTotalDownloadedSize() -> Int64 {
                    return chunks.reduce(Int64(0)) { $0 + $1.downloadedSize }
                }
            }
            
            let speedTracker = SpeedTracker()
            await speedTracker.initialize(initialSize: chunks.reduce(Int64(0)) { $0 + $1.downloadedSize })
            
            let chunkStateManager = ChunkStateManager(chunks: chunks)
            
            try await withThrowingTaskGroup(of: DownloadChunk.self) { group in
                let semaphore = AsyncSemaphore(value: chunkConcurrency)

                let initialChunks = await chunkStateManager.getAllChunks()
                saveChunkedDownloadState(packageIdentifier: packageIdentifier, chunks: initialChunks, totalSize: totalSize, destinationURL: destinationURL)
                
                for chunk in incompleteChunks {
                    if let cancellationHandler = cancellationHandler {
                        if await cancellationHandler() {
                            throw NetworkError.cancelled
                        }
                    }
                    
                    group.addTask {
                        await semaphore.wait()
                        defer {
                            Task {
                                await semaphore.signal()
                            }
                        }
                        
                        if let cancellationHandler = cancellationHandler {
                            if await cancellationHandler() {
                                throw NetworkError.cancelled
                            }
                        }
                        
                        return try await self.downloadChunkToFile(
                            chunk: chunk,
                            url: url,
                            destinationURL: destinationURL,
                            headers: headers,
                            progressHandler: { downloaded, total in
                                Task {
                                    await chunkStateManager.updateChunkProgress(
                                        index: chunk.index,
                                        downloadedSize: downloaded,
                                        isCompleted: downloaded >= total
                                    )
                                    
                                    let currentTotalDownloaded = await chunkStateManager.getTotalDownloadedSize()
                                    let progress = Double(currentTotalDownloaded) / Double(totalSize)
                                    
                                    let speed = await speedTracker.updateSpeed(currentDownloaded: currentTotalDownloaded)
                                    if speed > 0 {
                                        progressHandler?(progress, currentTotalDownloaded, totalSize, speed)
                                    }
                                }
                            },
                            cancellationHandler: cancellationHandler
                        )
                    }
                }

                do {
                    for try await completedChunk in group {
                        await chunkStateManager.updateChunk(completedChunk)

                        let currentChunks = await chunkStateManager.getAllChunks()
                        saveChunkedDownloadState(packageIdentifier: packageIdentifier, chunks: currentChunks, totalSize: totalSize, destinationURL: destinationURL)
                    }
                } catch {
                    let currentChunks = await chunkStateManager.getAllChunks()
                    saveChunkedDownloadState(packageIdentifier: packageIdentifier, chunks: currentChunks, totalSize: totalSize, destinationURL: destinationURL)
                    throw error
                }
            }

            clearChunkedDownloadState(packageIdentifier: packageIdentifier)
        }

        taskLock.lock()
        activeTasks[packageIdentifier] = downloadTask
        taskLock.unlock()
        
        defer {
            taskLock.lock()
            activeTasks.removeValue(forKey: packageIdentifier)
            taskLock.unlock()
        }

        try await downloadTask.value
    }
}
