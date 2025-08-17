//
//  PrivilegedHelperAdapter.swift
//  Adobe Downloader
//
//  Created by X1a0He on 2025/07/20.
//

import Foundation
import AppKit
import Combine

@objcMembers
class PrivilegedHelperAdapter: NSObject, ObservableObject {
    
    static let shared = PrivilegedHelperAdapter()
    static let machServiceName = "com.x1a0he.macOS.Adobe-Downloader.helper"
    
    @Published var connectionState: ConnectionState = .disconnected

    private let smJobBlessManager: SMJobBlessHelperManager
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
        self.smJobBlessManager = SMJobBlessHelperManager.shared
        super.init()

        smJobBlessManager.$connectionState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] smJobBlessState in
                self?.connectionState = self?.convertConnectionState(smJobBlessState) ?? .disconnected
            }
            .store(in: &cancellables)

        smJobBlessManager.connectionSuccessBlock = { [weak self] in
            self?.connectionSuccessBlock?()
        }
    }
    
    private var cancellables = Set<AnyCancellable>()

    func checkInstall() {
        smJobBlessManager.checkInstall()
    }
    
    func getHelperStatus(callback: @escaping ((HelperStatus) -> Void)) {
        smJobBlessManager.getHelperStatus { status in
            let legacyStatus = self.convertHelperStatus(status)
            callback(legacyStatus)
        }
    }
    
    static var getHelperStatus: Bool {
        return SMJobBlessHelperManager.getHelperStatus
    }

    func executeCommand(_ command: String, completion: @escaping (String) -> Void) {
        smJobBlessManager.executeCommand(command, completion: completion)
    }
    
    func executeInstallation(_ command: String, progress: @escaping (String) -> Void) async throws {
        try await smJobBlessManager.executeInstallation(command, progress: progress)
    }
    
    func reconnectHelper(completion: @escaping (Bool, String) -> Void) {
        smJobBlessManager.reconnectHelper(completion: completion)
    }
    
    func reinstallHelper(completion: @escaping (Bool, String) -> Void) {
        smJobBlessManager.reinstallHelper(completion: completion)
    }
    
    func removeInstallHelper(completion: ((Bool) -> Void)? = nil) {
        smJobBlessManager.removeInstallHelper(completion: completion)
    }
    
    func forceReinstallHelper() {
        smJobBlessManager.forceCleanAndReinstallHelper { success, message in
            print("Helper重新安装结果: \(success ? "成功" : "失败") - \(message)")
        }
    }
    
    func disconnectHelper() {
        smJobBlessManager.disconnectHelper()
    }
    
    func uninstallHelperViaTerminal(completion: @escaping (Bool, String) -> Void) {
        smJobBlessManager.uninstallHelperViaTerminal(completion: completion)
    }
    
    public func getHelperProxy() throws -> HelperToolProtocol {
        return try smJobBlessManager.getHelperProxy()
    }
    
    private func convertConnectionState(_ smJobBlessState: SMJobBlessHelperManager.ConnectionState) -> ConnectionState {
        switch smJobBlessState {
        case .connected:
            return .connected
        case .disconnected:
            return .disconnected
        case .connecting:
            return .connecting
        }
    }
    
    private func convertHelperStatus(_ smJobBlessStatus: SMJobBlessHelperManager.HelperStatus) -> HelperStatus {
        switch smJobBlessStatus {
        case .installed:
            return .installed
        case .noFound:
            return .noFound
        case .needUpdate:
            return .needUpdate
        }
    }
}
