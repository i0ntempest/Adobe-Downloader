import Foundation

class TaskPersistenceManager {
    static let shared = TaskPersistenceManager()
    
    private let fileManager = FileManager.default
    private var tasksDirectory: URL
    private weak var cancelTracker: CancelTracker?
    
    private init() {
        let containerURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        tasksDirectory = containerURL.appendingPathComponent("Adobe Downloader/tasks", isDirectory: true)
        try? fileManager.createDirectory(at: tasksDirectory, withIntermediateDirectories: true)
    }
    
    func setCancelTracker(_ tracker: CancelTracker) {
        self.cancelTracker = tracker
    }
    
    private func getTaskFileName(sapCode: String, version: String, language: String, platform: String) -> String {
        return sapCode == "APRO" 
            ? "Adobe Downloader \(sapCode)_\(version)_\(platform)-task.json"
            : "Adobe Downloader \(sapCode)_\(version)-\(language)-\(platform)-task.json"
    }
    
    func saveTask(_ task: NewDownloadTask) async {
        let fileName = getTaskFileName(
            sapCode: task.sapCode,
            version: task.version,
            language: task.language,
            platform: task.platform
        )
        let fileURL = tasksDirectory.appendingPathComponent(fileName)
        
        var resumeDataDict: [String: Data]? = nil
        
        if let currentPackage = task.currentPackage,
           let cancelTracker = self.cancelTracker,
           let resumeData = await cancelTracker.getResumeData(task.id) {
            resumeDataDict = [currentPackage.id.uuidString: resumeData]
        }
        
        let taskData = TaskData(
            sapCode: task.sapCode,
            version: task.version,
            language: task.language,
            displayName: task.displayName,
            directory: task.directory,
            productsToDownload: task.productsToDownload.map { product in
                ProductData(
                    sapCode: product.sapCode,
                    version: product.version,
                    buildGuid: product.buildGuid,
                    applicationJson: product.applicationJson,
                    packages: product.packages.map { package in
                        PackageData(
                            type: package.type,
                            fullPackageName: package.fullPackageName,
                            downloadSize: package.downloadSize,
                            downloadURL: package.downloadURL,
                            downloadedSize: package.downloadedSize,
                            progress: package.progress,
                            speed: package.speed,
                            status: package.status,
                            downloaded: package.downloaded,
                            packageVersion: package.packageVersion
                        )
                    }
                )
            },
            retryCount: task.retryCount,
            createAt: task.createAt,
            totalStatus: task.totalStatus ?? .waiting,
            totalProgress: task.totalProgress,
            totalDownloadedSize: task.totalDownloadedSize,
            totalSize: task.totalSize,
            totalSpeed: task.totalSpeed,
            displayInstallButton: task.displayInstallButton,
            platform: task.platform,
            resumeData: resumeDataDict
        )
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(taskData)
            // print("保存数据")
            try data.write(to: fileURL)
        } catch {
            print("Error saving task: \(error)")
        }
    }
    
    func loadTasks() -> [NewDownloadTask] {
        var tasks: [NewDownloadTask] = []
        
        do {
            let files = try fileManager.contentsOfDirectory(at: tasksDirectory, includingPropertiesForKeys: nil)
            for file in files where file.pathExtension == "json" {
                if let task = loadTask(from: file) {
                    tasks.append(task)
                }
            }
        } catch {
            print("Error loading tasks: \(error)")
        }
        
        return tasks
    }
    
    private func loadTask(from url: URL) -> NewDownloadTask? {
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let taskData = try decoder.decode(TaskData.self, from: data)
            
            let products = taskData.productsToDownload.map { productData -> ProductsToDownload in
                let product = ProductsToDownload(
                    sapCode: productData.sapCode,
                    version: productData.version,
                    buildGuid: productData.buildGuid,
                    applicationJson: productData.applicationJson ?? ""
                )
                
                product.packages = productData.packages.map { packageData -> Package in
                    let package = Package(
                        type: packageData.type,
                        fullPackageName: packageData.fullPackageName,
                        downloadSize: packageData.downloadSize,
                        downloadURL: packageData.downloadURL,
                        packageVersion: packageData.packageVersion
                    )
                    package.downloadedSize = packageData.downloadedSize
                    package.progress = packageData.progress
                    package.speed = packageData.speed
                    package.status = packageData.status
                    package.downloaded = packageData.downloaded
                    return package
                }
                
                return product
            }

            for product in products {
                for package in product.packages {
                    package.speed = 0
                }
            }
            
            let initialStatus: DownloadStatus
            switch taskData.totalStatus {
            case .completed(let info):
                initialStatus = .completed(info)
            case .failed(let info):
                initialStatus = .failed(info)
            case .downloading:
                initialStatus = .paused(DownloadStatus.PauseInfo(
                    reason: .other(String(localized: "程序退出")),
                    timestamp: Date(),
                    resumable: true
                ))
            default:
                initialStatus = .paused(DownloadStatus.PauseInfo(
                    reason: .other(String(localized: "程序重启后自动暂停")),
                    timestamp: Date(),
                    resumable: true
                ))
            }
            
            let task = NewDownloadTask(
                sapCode: taskData.sapCode,
                version: taskData.version,
                language: taskData.language,
                displayName: taskData.displayName,
                directory: taskData.directory,
                productsToDownload: products,
                retryCount: taskData.retryCount,
                createAt: taskData.createAt,
                totalStatus: initialStatus,
                totalProgress: taskData.totalProgress,
                totalDownloadedSize: taskData.totalDownloadedSize,
                totalSize: taskData.totalSize,
                totalSpeed: 0,
                currentPackage: products.first?.packages.first,
                platform: taskData.platform
            )
            task.displayInstallButton = taskData.displayInstallButton
            
            if let resumeData = taskData.resumeData?.values.first {
                Task {
                    if let cancelTracker = self.cancelTracker {
                        await cancelTracker.storeResumeData(task.id, data: resumeData)
                    }
                }
            }
            
            return task
        } catch {
            print("Error loading task from \(url): \(error)")
            return nil
        }
    }
    
    func removeTask(_ task: NewDownloadTask) {
        let fileName = getTaskFileName(
            sapCode: task.sapCode,
            version: task.version,
            language: task.language,
            platform: task.platform
        )
        let fileURL = tasksDirectory.appendingPathComponent(fileName)
        
        try? fileManager.removeItem(at: fileURL)
    }
}

private struct TaskData: Codable {
    let sapCode: String
    let version: String
    let language: String
    let displayName: String
    let directory: URL
    let productsToDownload: [ProductData]
    let retryCount: Int
    let createAt: Date
    let totalStatus: DownloadStatus
    let totalProgress: Double
    let totalDownloadedSize: Int64
    let totalSize: Int64
    let totalSpeed: Double
    let displayInstallButton: Bool
    let platform: String
    let resumeData: [String: Data]?
}

private struct ProductData: Codable {
    let sapCode: String
    let version: String
    let buildGuid: String
    let applicationJson: String?
    let packages: [PackageData]
}

private struct PackageData: Codable {
    let type: String
    let fullPackageName: String
    let downloadSize: Int64
    let downloadURL: String
    let downloadedSize: Int64
    let progress: Double
    let speed: Double
    let status: PackageStatus
    let downloaded: Bool
    let packageVersion: String
} 
