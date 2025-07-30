//
//  PrivilegedHelperAdapter.swift
//  Adobe Downloader
//
//  Created by X1a0He on 2025/07/20.
//

import Foundation
import AppKit
import ServiceManagement

@objcMembers
class PrivilegedHelperAdapter: NSObject, ObservableObject {
    
    static let shared = PrivilegedHelperAdapter()
    static let machServiceName = "com.x1a0he.macOS.Adobe-Downloader.helper"
    
    @Published var connectionState: ConnectionState = .disconnected

    private let modernManager: ModernPrivilegedHelperManager
    var connectionSuccessBlock: (() -> Void)?

    enum HelperStatus {
        case installed
        case noFound
        case needUpdate
    }
    
    enum ConnectionState {
        case connected
        case disconnected
        case connecting
        
        var description: String {
            switch self {
            case .connected:
                return String(localized: "已连接")
            case .disconnected:
                return String(localized: "未连接")
            case .connecting:
                return String(localized: "正在连接")
            }
        }
    }

    override init() {
        self.modernManager = ModernPrivilegedHelperManager.shared
        super.init()

        modernManager.$connectionState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] modernState in
                self?.connectionState = self?.convertConnectionState(modernState) ?? .disconnected
            }
            .store(in: &cancellables)

        Task {
            await initializeWithMigration()
        }
    }
    
    private var cancellables = Set<AnyCancellable>()

    func checkInstall() {
        Task {
            await modernManager.checkAndInstallHelper()
        }
    }
    
    func getHelperStatus(callback: @escaping ((HelperStatus) -> Void)) {
        Task {
            let modernStatus = await modernManager.getHelperStatus()
            let legacyStatus = convertHelperStatus(modernStatus)
            
            await MainActor.run {
                callback(legacyStatus)
            }
        }
    }
    
    static var getHelperStatus: Bool {
        let helperURL = Bundle.main.bundleURL.appendingPathComponent("Contents/Library/LaunchServices/" + machServiceName)
        guard CFBundleCopyInfoDictionaryForURL(helperURL as CFURL) != nil else { return false }

        let appService = SMAppService.daemon(plistName: machServiceName)
        return appService.status == .enabled
    }

    func executeCommand(_ command: String, completion: @escaping (String) -> Void) {
        modernManager.executeCommand(command, completion: completion)
    }
    
    func executeInstallation(_ command: String, progress: @escaping (String) -> Void) async throws {
        try await modernManager.executeInstallation(command, progress: progress)
    }
    
    func reconnectHelper(completion: @escaping (Bool, String) -> Void) {
        Task {
            do {
                try await modernManager.reconnectHelper()
                completion(true, String(localized: "重新连接成功"))
            } catch {
                completion(false, error.localizedDescription)
            }
        }
    }
    
    func reinstallHelper(completion: @escaping (Bool, String) -> Void) {
        Task {
            do {
                try await modernManager.uninstallHelper()
                await modernManager.checkAndInstallHelper()

                try await Task.sleep(nanoseconds: 2_000_000_000)
                
                let status = await modernManager.getHelperStatus()
                switch status {
                case .installed:
                    completion(true, String(localized: "重新安装成功"))
                case .needsApproval:
                    completion(false, String(localized: "需要在系统设置中批准"))
                default:
                    completion(false, String(localized: "重新安装失败"))
                }
            } catch {
                completion(false, error.localizedDescription)
            }
        }
    }
    
    func removeInstallHelper(completion: ((Bool) -> Void)? = nil) {
        Task {
            do {
                try await modernManager.uninstallHelper()
                completion?(true)
            } catch {
                completion?(false)
            }
        }
    }
    
    func forceReinstallHelper() {
        reinstallHelper { _, _ in }
    }
    
    func disconnectHelper() {
        Task {
            await modernManager.disconnectHelper()
        }
    }
    
    func uninstallHelperViaTerminal(completion: @escaping (Bool, String) -> Void) {
        Task {
            do {
                try await modernManager.uninstallHelper()
                completion(true, String(localized: "Helper 已完全卸载"))
            } catch {
                completion(false, error.localizedDescription)
            }
        }
    }
    
    public func getHelperProxy() throws -> HelperToolProtocol {
        return try modernManager.getHelperProxy()
    }
    
    private func initializeWithMigration() async {
        do {
            let _ = try await ModernPrivilegedHelperManager.initializeWithMigration()
            connectionSuccessBlock?()
        } catch {
            print("Helper 初始化失败: \(error)")
        }
    }
    
    private func convertConnectionState(_ modernState: ModernPrivilegedHelperManager.ConnectionState) -> ConnectionState {
        switch modernState {
        case .connected:
            return .connected
        case .disconnected:
            return .disconnected
        case .connecting:
            return .connecting
        case .needsApproval:
            return .disconnected
        }
    }
    
    private func convertHelperStatus(_ modernStatus: ModernPrivilegedHelperManager.HelperStatus) -> HelperStatus {
        switch modernStatus {
        case .installed:
            return .installed
        case .notInstalled, .needsApproval, .legacy:
            return .noFound
        case .requiresUpdate:
            return .needUpdate
        }
    }
}

import Combine
