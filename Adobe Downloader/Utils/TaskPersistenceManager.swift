import Foundation

class TaskPersistenceManager {
    static let shared = TaskPersistenceManager()
    
    private let fileManager = FileManager.default
    private var tasksDirectory: URL
    private weak var cancelTracker: CancelTracker?
    private var taskCache: [String: NewDownloadTask] = [:]
    
    private init() {
        let containerURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        tasksDirectory = containerURL.appendingPathComponent("Adobe Downloader/tasks", isDirectory: true)
        try? fileManager.createDirectory(at: tasksDirectory, withIntermediateDirectories: true)
    }
    
    func setCancelTracker(_ tracker: CancelTracker) {
        self.cancelTracker = tracker
    }
    
    private func getTaskFileName(productId: String, version: String, language: String, platform: String) -> String {
        return productId == "APRO"
        ? "Adobe Downloader \(productId)_\(version)_\(platform)-task.json"
            : "Adobe Downloader \(productId)_\(version)-\(language)-\(platform)-task.json"
    }
    
    func saveTask(_ task: NewDownloadTask) async {
        let fileName = getTaskFileName(
            productId: task.productId,
            version: task.productVersion,
            language: task.language,
            platform: task.platform
        )
        taskCache[fileName] = task
        let fileURL = tasksDirectory.appendingPathComponent(fileName)
        
        var resumeDataDict: [String: Data]? = nil
        
        if let currentPackage = task.currentPackage,
           let cancelTracker = self.cancelTracker,
           let resumeData = await cancelTracker.getResumeData(task.id) {
            resumeDataDict = [currentPackage.id.uuidString: resumeData]
        }
        
        let taskData = TaskData(
            sapCode: task.productId,
            version: task.productVersion,
            language: task.language,
            displayName: task.displayName,
            directory: task.directory,
            productsToDownload: task.dependenciesToDownload.map { product in
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
    
    func loadTasks() async -> [NewDownloadTask] {
        var tasks: [NewDownloadTask] = []
        
        do {
            let files = try fileManager.contentsOfDirectory(at: tasksDirectory, includingPropertiesForKeys: nil)
            for file in files where file.pathExtension == "json" {
                let fileName = file.lastPathComponent
                if let cachedTask = taskCache[fileName] {
                    tasks.append(cachedTask)
                } else if let task = await loadTask(from: file) {
                    taskCache[fileName] = task
                    tasks.append(task)
                }
            }
        } catch {
            print("Error loading tasks: \(error)")
        }
        
        return tasks
    }
    
    private func loadTask(from url: URL) async -> NewDownloadTask? {
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let taskData = try decoder.decode(TaskData.self, from: data)
            
            let products = taskData.productsToDownload.map { productData -> DependenciesToDownload in
                let product = DependenciesToDownload(
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
                productId: taskData.sapCode,
                productVersion: taskData.version,
                language: taskData.language,
                displayName: taskData.displayName,
                directory: taskData.directory,
                dependenciesToDownload: products,
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
            productId: task.productId,
            version: task.productVersion,
            language: task.language,
            platform: task.platform
        )
        let fileURL = tasksDirectory.appendingPathComponent(fileName)
        
        taskCache.removeValue(forKey: fileName)
        try? fileManager.removeItem(at: fileURL)
    }
    
    func createExistingProgramTask(productId: String, version: String, language: String, displayName: String, platform: String, directory: URL) async {
        let fileName = getTaskFileName(
            productId: productId,
            version: version,
            language: language,
            platform: platform
        )
        
        let product = DependenciesToDownload(
            sapCode: productId,
            version: version,
            buildGuid: "",
            applicationJson: ""
        )
        
        let package = Package(
            type: "",
            fullPackageName: "",
            downloadSize: 0,
            downloadURL: "",
            packageVersion: version
        )
        package.downloaded = true
        package.progress = 1.0
        package.status = .completed
        
        product.packages = [package]
        
        let task = NewDownloadTask(
            productId: productId,
            productVersion: version,
            language: language,
            displayName: displayName,
            directory: directory,
            dependenciesToDownload: [product],
            retryCount: 0,
            createAt: Date(),
            totalStatus: .completed(DownloadStatus.CompletionInfo(
                timestamp: Date(),
                totalTime: 0,
                totalSize: 0
            )),
            totalProgress: 1.0,
            totalDownloadedSize: 0,
            totalSize: 0,
            totalSpeed: 0,
            currentPackage: package,
            platform: platform
        )
        task.displayInstallButton = true
        
        taskCache[fileName] = task
        await saveTask(task)
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
