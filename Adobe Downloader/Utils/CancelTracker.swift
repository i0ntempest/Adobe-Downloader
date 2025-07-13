//
//  Adobe Downloader
//
//  Created by X1a0He on 2024/10/30.
//
import Foundation

actor CancelTracker {
    private var cancelledIds: Set<UUID> = []
    private var pausedIds: Set<UUID> = []
    var downloadTasks: [UUID: URLSessionDownloadTask] = [:]
    private var sessions: [UUID: URLSession] = [:]
    private var taskPackageIdentifiers: [UUID: String] = [:]
    private var taskFirstDataFlags: [UUID: AsyncFlag] = [:]

    func registerTask(_ id: UUID, task: URLSessionDownloadTask, session: URLSession, packageIdentifier: String = "", hasReceivedFirstData: AsyncFlag? = nil) {
        downloadTasks[id] = task
        sessions[id] = session
        if !packageIdentifier.isEmpty {
            taskPackageIdentifiers[id] = packageIdentifier
        }
        if let flag = hasReceivedFirstData {
            taskFirstDataFlags[id] = flag
        }
    }
    
    func cancel(_ id: UUID) {
        cancelledIds.insert(id)
        pausedIds.remove(id)
        taskPackageIdentifiers.removeValue(forKey: id)
        taskFirstDataFlags.removeValue(forKey: id)
        
        if let task = downloadTasks[id] {
            task.cancel()
            downloadTasks.removeValue(forKey: id)
        }
        
        if let session = sessions[id] {
            session.invalidateAndCancel()
            sessions.removeValue(forKey: id)
        }
    }
    
    func pause(_ id: UUID) async {
        if !cancelledIds.contains(id) {
            pausedIds.insert(id)
            if let task = downloadTasks[id] {
                task.cancel()
            }
        }
    }
    
    func resume(_ id: UUID) {
        if pausedIds.contains(id) {
            pausedIds.remove(id)
        }
    }
    
    func isCancelled(_ id: UUID) -> Bool {
        return cancelledIds.contains(id)
    }
    
    func isPaused(_ id: UUID) -> Bool {
        return pausedIds.contains(id)
    }
    
    func cleanupCompletedTasks() {
        let completedTaskIds = downloadTasks.compactMap { (id, task) in
            task.state == .completed || task.state == .canceling ? id : nil
        }
        
        for taskId in completedTaskIds {
            downloadTasks.removeValue(forKey: taskId)
            sessions.removeValue(forKey: taskId)
            taskPackageIdentifiers.removeValue(forKey: taskId)
            taskFirstDataFlags.removeValue(forKey: taskId)
        }
    }
    
    func getActiveTasksInfo() -> (total: Int, running: Int, suspended: Int) {
        let total = downloadTasks.count
        let running = downloadTasks.values.filter { $0.state == .running }.count
        let suspended = downloadTasks.values.filter { $0.state == .suspended }.count
        return (total: total, running: running, suspended: suspended)
    }
    
    func getTaskPackageMap() -> [UUID: (task: URLSessionDownloadTask, packageIdentifier: String, hasReceivedFirstData: AsyncFlag?)] {
        var result: [UUID: (URLSessionDownloadTask, String, AsyncFlag?)] = [:]
        for (id, task) in downloadTasks {
            let packageId = taskPackageIdentifiers[id] ?? ""
            let firstDataFlag = taskFirstDataFlags[id]
            result[id] = (task, packageId, firstDataFlag)
        }
        return result
    }
} 
