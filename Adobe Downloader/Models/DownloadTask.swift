//
//  Adobe Downloader
//
//  Created by X1a0He on 2024/10/30.
//
import Foundation

extension DownloadStatus {
    var isCompleted: Bool {
        if case .completed = self {
            return true
        }
        return false
    }
    
    var isFailed: Bool {
        if case .failed = self {
            return true
        }
        return false
    }
}

//class NewDownloadTask: Identifiable, ObservableObject, Equatable  {
//    let id = UUID()
//    var sapCode: String
//    let version: String
//    let language: String
//    let displayName: String
//    let directory: URL
//    var productsToDownload: [ProductsToDownload]
//    var retryCount: Int
//    let createAt: Date
//    var displayInstallButton: Bool
//    @Published var totalStatus: DownloadStatus?
//    @Published var totalProgress: Double
//    @Published var totalDownloadedSize: Int64
//    @Published var totalSize: Int64
//    @Published var totalSpeed: Double
//    @Published var currentPackage: Package? {
//        didSet {
//            objectWillChange.send()
//        }
//    }
//    let platform: String
//
//    var status: DownloadStatus {
//        totalStatus ?? .waiting
//    }
//
//    var destinationURL: URL { directory }
//
//    var downloadedSize: Int64 {
//        get { totalDownloadedSize }
//        set { totalDownloadedSize = newValue }
//    }
//
//    var progress: Double {
//        get { totalProgress }
//        set { totalProgress = newValue }
//    }
//
//    var speed: Double {
//        get { totalSpeed }
//        set { totalSpeed = newValue }
//    }
//
//    var formattedTotalSize: String {
//        ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
//    }
//
//    var formattedDownloadedSize: String {
//        ByteCountFormatter.string(fromByteCount: totalDownloadedSize, countStyle: .file)
//    }
//
//    @Published var completedPackages: Int = 0
//    @Published var totalPackages: Int = 0
//
//    func setStatus(_ newStatus: DownloadStatus) {
//        DispatchQueue.main.async {
//            self.totalStatus = newStatus
//            self.objectWillChange.send()
//        }
//    }
//
//    func updateProgress(downloaded: Int64, total: Int64, speed: Double) {
//        DispatchQueue.main.async {
//            self.totalDownloadedSize = downloaded
//            self.totalSize = total
//            self.totalSpeed = speed
//            self.totalProgress = total > 0 ? Double(downloaded) / Double(total) : 0
//            self.objectWillChange.send()
//        }
//    }
//
//    init(sapCode: String, version: String, language: String, displayName: String, directory: URL, productsToDownload: [ProductsToDownload] = [], retryCount: Int = 0, createAt: Date, totalStatus: DownloadStatus? = nil, totalProgress: Double, totalDownloadedSize: Int64 = 0, totalSize: Int64 = 0, totalSpeed: Double = 0, currentPackage: Package? = nil, platform: String) {
//        self.sapCode = sapCode
//        self.version = version
//        self.language = language
//        self.displayName = displayName
//        self.directory = directory
//        self.productsToDownload = productsToDownload
//        self.retryCount = retryCount
//        self.createAt = createAt
//        self.totalStatus = totalStatus
//        self.totalProgress = totalProgress
//        self.totalDownloadedSize = totalDownloadedSize
//        self.totalSize = totalSize
//        self.totalSpeed = totalSpeed
//        self.currentPackage = currentPackage
//        self.displayInstallButton = sapCode != "APRO"
//        self.platform = platform
//    }
//
//    static func == (lhs: NewDownloadTask, rhs: NewDownloadTask) -> Bool {
//        return lhs.id == rhs.id
//    }
//}
