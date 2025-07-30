//
//  ModernPrivilegedHelperManager.swift
//  Adobe Downloader
//
//  Created by X1a0He on 2025/07/20.
//

import AppKit
import Cocoa
import ServiceManagement
import os.log

@objc enum CommandType: Int {
    case install
    case uninstall
    case moveFile
    case setPermissions
    case shellCommand
}

@objc(HelperToolProtocol) protocol HelperToolProtocol {
    @objc(executeCommand:path1:path2:permissions:withReply:)
    func executeCommand(type: CommandType, path1: String, path2: String, permissions: Int, withReply reply: @escaping (String) -> Void)
    func getInstallationOutput(withReply reply: @escaping (String) -> Void)
}

@objcMembers
class ModernPrivilegedHelperManager: NSObject, ObservableObject {

    enum HelperStatus {
        case installed
        case notInstalled
        case needsApproval
        case requiresUpdate
        case legacy
    }
    
    enum ConnectionState {
        case connected
        case disconnected
        case connecting
        case needsApproval
        
        var description: String {
            switch self {
            case .connected:
                return String(localized: "已连接")
            case .disconnected:
                return String(localized: "未连接")
            case .connecting:
                return String(localized: "正在连接")
            case .needsApproval:
                return String(localized: "需要批准")
            }
        }
    }
    
    enum HelperError: LocalizedError {
        case serviceUnavailable
        case connectionFailed
        case proxyError
        case authorizationFailed
        case installationFailed(String)
        case legacyInstallationDetected
        
        var errorDescription: String? {
            switch self {
            case .serviceUnavailable:
                return String(localized: "Helper 服务不可用")
            case .connectionFailed:
                return String(localized: "无法连接到 Helper")
            case .proxyError:
                return String(localized: "无法获取 Helper 代理")
            case .authorizationFailed:
                return String(localized: "获取授权失败")
            case .installationFailed(let reason):
                return String(localized: "安装失败: \(reason)")
            case .legacyInstallationDetected:
                return String(localized: "检测到旧版本安装，需要清理")
            }
        }
    }

    static let shared = ModernPrivilegedHelperManager()
    static let helperIdentifier = "com.x1a0he.macOS.Adobe-Downloader.helper"
    
    private let logger = Logger(subsystem: "com.x1a0he.macOS.Adobe-Downloader", category: "HelperManager")
    
    @Published private(set) var connectionState: ConnectionState = .disconnected
    
    private var appService: SMAppService?
    private var connection: NSXPCConnection?
    private let connectionQueue = DispatchQueue(label: "com.x1a0he.macOS.Adobe-Downloader.helper.connection")
    
    var connectionSuccessBlock: (() -> Void)?
    private var shouldAutoReconnect = true
    private var isInitializing = false

    override init() {
        super.init()
        initializeAppService()
        setupAutoReconnect()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleConnectionInvalidation),
            name: .NSXPCConnectionInvalid,
            object: nil
        )
    }
    
    private func initializeAppService() {
        appService = SMAppService.daemon(plistName: "com.x1a0he.macOS.Adobe-Downloader.helper.plist")
    }
    
    private func setupAutoReconnect() {
        Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.connectionState == .disconnected && self.shouldAutoReconnect && !self.isInitializing {
                self.logger.info("尝试自动重连Helper...")
                Task {
                    await self.attemptConnection()
                }
            }
        }
    }

    func checkAndInstallHelper() async {
        isInitializing = true
        logger.info("开始检查 Helper 状态")
        
        let status = await getHelperStatus()
        
        await MainActor.run {
            switch status {
            case .legacy:
                handleLegacyInstallation()
                break
            case .notInstalled:
                registerHelper()
                break
            case .needsApproval:
                self.connectionState = .needsApproval
                showApprovalGuidance()
                break
            case .requiresUpdate:
                updateHelper()
                break
            case .installed:
                Task {
                    let connectionResult = await attemptConnection()
                    if connectionResult {
                        logger.info("Helper 连接成功")
                        connectionSuccessBlock?()
                    } else {
                        logger.warning("Helper 安装成功但连接失败，可能存在权限问题")
                        await MainActor.run {
                            self.connectionState = .disconnected
                        }
                    }
                    self.isInitializing = false
                }
            }
        }
    }

    func getHelperStatus() async -> HelperStatus {
        guard let appService = appService else {
            return .notInstalled
        }

        if hasLegacyInstallation() {
            return .legacy
        }
        
        let status = appService.status
        logger.info("SMAppService 状态: \(status.rawValue)")
        
        switch status {
        case .notRegistered:
            return .notInstalled
            
        case .enabled:
            if await needsUpdate() {
                return .requiresUpdate
            }
            return .installed
            
        case .requiresApproval:
            logger.info("Helper需要用户批准")
            return .needsApproval
            
        case .notFound:
            return .notInstalled
            
        @unknown default:
            logger.warning("未知的 SMAppService 状态: \(status.rawValue)")
            return .needsApproval
        }
    }

    private func registerHelper() {
        guard let appService = appService else {
            logger.error("SMAppService 未初始化")
            return
        }
        
        do {
            try appService.register()
            logger.info("Helper 注册成功")

            if let currentBuild = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                UserDefaults.standard.set(currentBuild, forKey: "InstalledHelperBuild")
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                Task {
                    await self.tryEnableHelper()
                }
            }
            
        } catch {
            logger.error("Helper 注册失败: \(error)")
            handleRegistrationError(error)
            isInitializing = false
        }
    }
    
    private func tryEnableHelper() async {
        guard let appService = appService else { return }

        let currentStatus = appService.status
        logger.info("尝试启用Helper，当前状态: \(currentStatus.rawValue)")

        if currentStatus != .enabled {
            do {
                logger.info("尝试重新注册Helper以启用")
                try appService.register()

                try await Task.sleep(nanoseconds: 2_000_000_000)
                
                let newStatus = appService.status
                logger.info("重新注册后状态: \(newStatus.rawValue)")
                
                if newStatus == .enabled {
                    logger.info("Helper成功启用")
                    let connectionResult = await attemptConnection()
                    if connectionResult {
                        logger.info("Helper连接成功")
                        return
                    }
                }
            } catch {
                logger.error("重新注册失败: \(error)")
            }
        }

        let connectionResult = await attemptConnection()
        if !connectionResult {
            logger.warning("Helper 注册成功但连接失败，需要用户批准")
            await MainActor.run {
                self.connectionState = .needsApproval
                self.showApprovalGuidance()
            }
        }
        
        self.isInitializing = false
    }

    private func updateHelper() {
        registerHelper()
    }

    func uninstallHelper() async throws {
        shouldAutoReconnect = false
        await disconnectHelper()

        if let appService = appService {
            do {
                try await appService.unregister()
                logger.info("SMAppService 卸载成功")
            } catch {
                logger.error("SMAppService 卸载失败: \(error)")
                throw error
            }
        }

        try await cleanupLegacyInstallation()

        UserDefaults.standard.removeObject(forKey: "InstalledHelperBuild")
        
        await MainActor.run {
            connectionState = .disconnected
        }
    }

    @discardableResult
    private func attemptConnection() async -> Bool {
        return connectionQueue.sync {
            createConnection() != nil
        }
    }

    private func createConnection() -> NSXPCConnection? {
        DispatchQueue.main.async {
            self.connectionState = .connecting
        }

        if let existingConnection = connection {
            existingConnection.invalidate()
            connection = nil
        }

        let newConnection = NSXPCConnection(machServiceName: Self.helperIdentifier, options: .privileged)

        let interface = NSXPCInterface(with: HelperToolProtocol.self)
        interface.setClasses(
            NSSet(array: [NSString.self, NSNumber.self]) as! Set<AnyHashable>,
            for: #selector(HelperToolProtocol.executeCommand(type:path1:path2:permissions:withReply:)),
            argumentIndex: 1,
            ofReply: false
        )
        newConnection.remoteObjectInterface = interface

        newConnection.interruptionHandler = { [weak self] in
            self?.logger.warning("XPC 连接中断")
            DispatchQueue.main.async {
                self?.connectionState = .disconnected
                self?.connection = nil
            }
        }
        
        newConnection.invalidationHandler = { [weak self] in
            self?.logger.info("XPC 连接失效")
            DispatchQueue.main.async {
                self?.connectionState = .disconnected
                self?.connection = nil
            }
        }
        
        newConnection.resume()

        let semaphore = DispatchSemaphore(value: 0)
        var isConnected = false
        
        if let helper = newConnection.remoteObjectProxy as? HelperToolProtocol {
            helper.executeCommand(type: .shellCommand, path1: "whoami", path2: "", permissions: 0) { [weak self] result in
                let trimmedResult = result.trimmingCharacters(in: .whitespacesAndNewlines)
                self?.logger.info("Helper 响应: \(trimmedResult)")
                
                if trimmedResult == "root" {
                    isConnected = true
                    DispatchQueue.main.async {
                        self?.connection = newConnection
                        self?.connectionState = .connected
                        self?.logger.info("Helper 权限验证成功，当前用户: \(trimmedResult)")
                    }
                } else if !trimmedResult.starts(with: "Error:") && !trimmedResult.isEmpty {
                    isConnected = true
                    DispatchQueue.main.async {
                        self?.connection = newConnection
                        self?.connectionState = .connected
                        self?.logger.warning("Helper 连接成功但权限可能不足，当前用户: \(trimmedResult)")
                    }
                } else {
                    self?.logger.error("Helper 连接失败或权限不足: \(trimmedResult)")
                }
                semaphore.signal()
            }
            let waitResult = semaphore.wait(timeout: .now() + 8.0)
            if waitResult == .timedOut {
                logger.warning("Helper 连接超时")
            }
        }
        
        if !isConnected {
            newConnection.invalidate()
            DispatchQueue.main.async {
                self.connectionState = .disconnected
            }
            return nil
        }
        
        logger.info("XPC 连接建立成功")
        return newConnection
    }

    func disconnectHelper() async {
        connectionQueue.sync {
            connection?.invalidate()
            connection = nil
            
            DispatchQueue.main.async {
                self.connectionState = .disconnected
            }
        }
    }

    func reconnectHelper() async throws {
        logger.info("开始重新连接Helper")
        shouldAutoReconnect = true
        await disconnectHelper()

        try await Task.sleep(nanoseconds: 500_000_000) // 0.5秒

        let connectionResult = await attemptConnection()
        if connectionResult {
            logger.info("重新连接成功")
        } else {
            logger.error("重新连接失败")
            throw HelperError.connectionFailed
        }
    }

    func getHelperProxy() throws -> HelperToolProtocol {
        if connectionState != .connected || connection == nil {
            guard let newConnection = connectionQueue.sync(execute: { createConnection() }) else {
                throw HelperError.connectionFailed
            }
            connection = newConnection
        }
        
        guard let helper = connection?.remoteObjectProxyWithErrorHandler({ [weak self] error in
            self?.logger.error("XPC 代理错误: \(error)")
            DispatchQueue.main.async {
                self?.connectionState = .disconnected
            }
        }) as? HelperToolProtocol else {
            throw HelperError.proxyError
        }
        
        return helper
    }

    func executeCommand(_ command: String, completion: @escaping (String) -> Void) {
        do {
            let helper = try getHelperProxy()
            
            if command.contains("perl") || command.contains("codesign") || command.contains("xattr") {
                helper.executeCommand(type: .shellCommand, path1: command, path2: "", permissions: 0) { [weak self] result in
                    DispatchQueue.main.async {
                        self?.updateConnectionState(from: result)
                        completion(result)
                    }
                }
                return
            }
            
            let (type, path1, path2, permissions) = parseCommand(command)
            
            helper.executeCommand(type: type, path1: path1, path2: path2, permissions: permissions) { [weak self] result in
                DispatchQueue.main.async {
                    self?.updateConnectionState(from: result)
                    completion(result)
                }
            }
        } catch {
            DispatchQueue.main.async { [weak self] in
                self?.connectionState = .disconnected
                self?.logger.error("执行命令失败: \(error.localizedDescription)")
                completion("Error: \(error.localizedDescription)")
            }
        }
    }

    func executeInstallation(_ command: String, progress: @escaping (String) -> Void) async throws {
        let helper: HelperToolProtocol = try connectionQueue.sync {
            if let existingConnection = connection,
               let proxy = existingConnection.remoteObjectProxy as? HelperToolProtocol {
                return proxy
            }
            
            guard let newConnection = createConnection() else {
                throw HelperError.connectionFailed
            }
            
            connection = newConnection
            
            guard let proxy = newConnection.remoteObjectProxy as? HelperToolProtocol else {
                throw HelperError.proxyError
            }
            
            return proxy
        }
        
        let (type, path1, path2, permissions) = parseCommand(command)
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            helper.executeCommand(type: type, path1: path1, path2: path2, permissions: permissions) { result in
                if result == "Started" || result == "Success" {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: HelperError.installationFailed(result))
                }
            }
        }

        while true {
            let output = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
                helper.getInstallationOutput { result in
                    continuation.resume(returning: result)
                }
            }
            
            if !output.isEmpty {
                progress(output)
            }
            
            if output.contains("Exit Code:") || output.range(of: "Progress: \\d+/\\d+", options: .regularExpression) != nil {
                if output.range(of: "Progress: \\d+/\\d+", options: .regularExpression) != nil {
                    progress("Exit Code: 0")
                }
                break
            }
            
            try await Task.sleep(nanoseconds: 100_000_000)
        }
    }

    private func updateConnectionState(from result: String) {
        DispatchQueue.main.async { [weak self] in
            if result.starts(with: "Error:") {
                self?.connectionState = .disconnected
                self?.logger.warning("命令执行失败，连接状态设为断开: \(result)")
            } else {
                self?.connectionState = .connected
            }
        }
    }
    
    private func parseCommand(_ command: String) -> (CommandType, String, String, Int) {
        let components = command.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        
        if command.hasPrefix("installer -pkg") {
            return (.install, components[2], "", 0)
        } else if command.hasPrefix("rm -rf") {
            let path = components.dropFirst(2).joined(separator: " ")
            return (.uninstall, path, "", 0)
        } else if command.hasPrefix("mv") || command.hasPrefix("cp") {
            let paths = components.dropFirst(1)
            let sourcePath = String(paths.first ?? "")
            let destPath = paths.dropFirst().joined(separator: " ")
            return (.moveFile, sourcePath, destPath, 0)
        } else if command.hasPrefix("chmod") {
            return (.setPermissions,
                   components.dropFirst(2).joined(separator: " "),
                   "",
                   Int(components[1]) ?? 0)
        }
        
        return (.shellCommand, command, "", 0)
    }
    
    private func needsUpdate() async -> Bool {
        guard let currentBuild = Bundle.main.infoDictionary?["CFBundleVersion"] as? String,
              let installedBuild = UserDefaults.standard.string(forKey: "InstalledHelperBuild") else {
            return true
        }
        
        return currentBuild != installedBuild
    }
    
    @objc private func handleConnectionInvalidation() {
        DispatchQueue.main.async { [weak self] in
            self?.connectionState = .disconnected
            self?.connection?.invalidate()
            self?.connection = nil
        }
    }

    private func hasLegacyInstallation() -> Bool {
        let legacyPlistPath = "/Library/LaunchDaemons/\(Self.helperIdentifier).plist"
        let legacyHelperPath = "/Library/PrivilegedHelperTools/\(Self.helperIdentifier)"
        
        return FileManager.default.fileExists(atPath: legacyPlistPath) ||
               FileManager.default.fileExists(atPath: legacyHelperPath)
    }

    private func handleLegacyInstallation() {
        logger.info("检测到旧的 SMJobBless 安装，开始清理")
        
        let alert = NSAlert()
        alert.messageText = String(localized: "检测到旧版本的 Helper")
        alert.informativeText = String(localized: "系统检测到旧版本的 Adobe Downloader Helper，需要升级到新版本。这将需要管理员权限来清理旧安装。")
        alert.addButton(withTitle: String(localized: "升级"))
        alert.addButton(withTitle: String(localized: "取消"))
        
        if alert.runModal() == .alertFirstButtonReturn {
            Task {
                do {
                    try await cleanupLegacyInstallation()
                    registerHelper()
                } catch {
                    logger.error("清理旧安装失败: \(error)")
                    showError("清理旧版本失败: \(error.localizedDescription)")
                }
            }
        }
    }

    private func cleanupLegacyInstallation() async throws {
        let script = """
        #!/bin/bash
        sudo /bin/launchctl unload /Library/LaunchDaemons/\(Self.helperIdentifier).plist 2>/dev/null
        sudo /bin/rm -f /Library/LaunchDaemons/\(Self.helperIdentifier).plist
        sudo /bin/rm -f /Library/PrivilegedHelperTools/\(Self.helperIdentifier)
        sudo /usr/bin/killall -u root -9 \(Self.helperIdentifier) 2>/dev/null || true
        exit 0
        """
        
        let tempDir = FileManager.default.temporaryDirectory
        let scriptURL = tempDir.appendingPathComponent("cleanup_legacy_helper.sh")
        
        try script.write(to: scriptURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)
        
        return try await withCheckedThrowingContinuation { continuation in
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            task.arguments = ["-e", "do shell script \"\(scriptURL.path)\" with administrator privileges"]
            
            do {
                try task.run()
                task.waitUntilExit()
                
                try? FileManager.default.removeItem(at: scriptURL)
                
                if task.terminationStatus == 0 {
                    logger.info("旧安装清理成功")
                    continuation.resume()
                } else {
                    continuation.resume(throwing: HelperError.installationFailed("清理脚本执行失败"))
                }
            } catch {
                try? FileManager.default.removeItem(at: scriptURL)
                continuation.resume(throwing: error)
            }
        }
    }

    private func showApprovalGuidance() {
        let alert = NSAlert()
        alert.messageText = String(localized: "Helper服务需要批准")
        alert.informativeText = String(localized: """
        Adobe Downloader需要后台Helper服务来执行安装和文件操作。
        
        解决方法：
        1. 点击下方「打开系统设置」按钮
        2. 在「登录项与扩展」中找到 Adobe Downloader
        3. 确保应用已被允许，并检查是否有任何需要启用的后台项目
        4. 如果看不到相关选项，请尝试：
           - 重启 Adobe Downloader
           - 或重启系统后再试
        
        注意：macOS可能需要重启才能完全激活Helper服务。
        """)
        alert.addButton(withTitle: String(localized: "打开系统设置"))
        alert.addButton(withTitle: String(localized: "稍后设置"))
        
        if alert.runModal() == .alertFirstButtonReturn {
            SMAppService.openSystemSettingsLoginItems()
        }
    }

    private func handleRegistrationError(_ error: Error) {
        logger.error("Helper 注册错误: \(error)")
        
        let nsError = error as NSError
        
        let message = String(localized: "Helper 注册失败")
        var informative = error.localizedDescription

        if nsError.domain == "com.apple.ServiceManagement.SMAppServiceError" {
            switch nsError.code {
            case 1: // kSMAppServiceErrorDomain
                informative = String(localized: "Helper 文件不存在或损坏，请重新安装应用")
            case 2: // Permission denied
                informative = String(localized: "权限被拒绝，请检查应用签名和权限设置")
            default:
                break
            }
        }
        
        showError(message, informative: informative)
    }

    private func showError(_ message: String, informative: String? = nil) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = message
            if let informative = informative {
                alert.informativeText = informative
            }
            alert.alertStyle = .warning
            alert.addButton(withTitle: String(localized: "确定"))
            alert.runModal()
        }
    }
}

fileprivate extension Notification.Name {
    static let NSXPCConnectionInvalid = Notification.Name("NSXPCConnectionInvalidNotification")
}
