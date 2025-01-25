//
//  Untitled.swift
//  Adobe Downloader
//
//  Created by X1a0He on 11/12/24.
//

import AppKit
import Cocoa
import ServiceManagement

@objc enum CommandType: Int {
    case install
    case uninstall
    case moveFile
    case setPermissions
    case shellCommand
}

@objc protocol HelperToolProtocol {
    @objc(executeCommand:path1:path2:permissions:withReply:)
    func executeCommand(type: CommandType, path1: String, path2: String, permissions: Int, withReply reply: @escaping (String) -> Void)
    func getInstallationOutput(withReply reply: @escaping (String) -> Void)
}

@objcMembers
class PrivilegedHelperManager: NSObject {

    enum HelperStatus {
        case installed
        case noFound
        case needUpdate
    }

    static let shared = PrivilegedHelperManager()
    static let machServiceName = "com.x1a0he.macOS.Adobe-Downloader.helper"
    var connectionSuccessBlock: (() -> Void)?

    private var useLegacyInstall = false
    private var connection: NSXPCConnection?

    @Published private(set) var connectionState: ConnectionState = .disconnected {
        didSet {
            if oldValue != connectionState {
                if connectionState == .disconnected {
                    connection?.invalidate()
                    connection = nil
                }
            }
        }
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

    private var isInitializing = false

    private let connectionQueue = DispatchQueue(label: "com.x1a0he.helper.connection")

    override init() {
        super.init()
        initAuthorizationRef()
        setupAutoReconnect()

        NotificationCenter.default.addObserver(self, 
                                             selector: #selector(handleConnectionInvalidation), 
                                             name: .NSXPCConnectionInvalid, 
                                             object: nil)
    }

    @objc private func handleConnectionInvalidation() {
        DispatchQueue.main.async { [weak self] in
            self?.connectionState = .disconnected
            self?.connection?.invalidate()
            self?.connection = nil
        }
    }

    func checkInstall() {
        if let currentBuild = Bundle.main.infoDictionary?["CFBundleVersion"] as? String,
           let installedBuild = UserDefaults.standard.string(forKey: "InstalledHelperBuild") {
            if currentBuild != installedBuild {
                notifyInstall()
                return
            }
        }

        getHelperStatus { [weak self] status in
            guard let self = self else { return }
            switch status {
            case .noFound:
                if #available(macOS 13, *) {
                    let url = URL(string: "/Library/LaunchDaemons/\(PrivilegedHelperManager.machServiceName).plist")!
                    let status = SMAppService.statusForLegacyPlist(at: url)
                    if status == .requiresApproval {
                        let alert = NSAlert()
                        let notice = String(localized: "Adobe Downloader 需要通过后台Daemon进程来安装与移动文件，请在\"系统偏好设置->登录项->允许在后台 中\"允许当前App")
                        let addition = String(localized: "如果在设置里没找到当前App，可以尝试重置守护程序")
                        alert.messageText = notice + "\n" + addition
                        alert.addButton(withTitle: "打开系统登录项设置")
                        alert.addButton(withTitle: "重置守护程序")
                        if alert.runModal() == .alertFirstButtonReturn {
                            SMAppService.openSystemSettingsLoginItems()
                        } else {
                             removeInstallHelper()
                        }
                    }
                }
                fallthrough
            case .needUpdate:
                if Thread.isMainThread {
                    self.notifyInstall()
                } else {
                    DispatchQueue.main.async {
                        self.notifyInstall()
                    }
                }
            case .installed:
                self.connectionSuccessBlock?()
            }
        }
    }

    private func initAuthorizationRef() {
        var authRef: AuthorizationRef?
        let status = AuthorizationCreate(nil, nil, AuthorizationFlags(), &authRef)
        if status != OSStatus(errAuthorizationSuccess) {
            return
        }
    }

    private func installHelperDaemon() -> DaemonInstallResult {
        var authRef: AuthorizationRef?
        var authStatus = AuthorizationCreate(nil, nil, [], &authRef)

        guard authStatus == errAuthorizationSuccess else {
            return .authorizationFail
        }

        var authItem = AuthorizationItem(name: (kSMRightBlessPrivilegedHelper as NSString).utf8String!, valueLength: 0, value: nil, flags: 0)
        var authRights = withUnsafeMutablePointer(to: &authItem) { pointer in
            AuthorizationRights(count: 1, items: pointer)
        }
        let flags: AuthorizationFlags = [[], .interactionAllowed, .extendRights, .preAuthorize]
        authStatus = AuthorizationCreate(&authRights, nil, flags, &authRef)
        defer {
            if let ref = authRef {
                AuthorizationFree(ref, [])
            }
        }
        guard authStatus == errAuthorizationSuccess else {
            return .getAdminFail
        }

        var error: Unmanaged<CFError>?
        
        if SMJobBless(kSMDomainSystemLaunchd, PrivilegedHelperManager.machServiceName as CFString, authRef, &error) == false {
            if let blessError = error?.takeRetainedValue() {
                let nsError = blessError as Error as NSError
                NSAlert.alert(with: "SMJobBless failed with error: \(blessError)\nError domain: \(nsError.domain)\nError code: \(nsError.code)\nError description: \(nsError.localizedDescription)\nError user info: \(nsError.userInfo)")
                return .blessError(nsError.code)
            }
            return .blessError(-1)
        }
        
        if let currentBuild = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            UserDefaults.standard.set(currentBuild, forKey: "InstalledHelperBuild")
        }
        return .success
    }

    func getHelperStatus(callback: @escaping ((HelperStatus) -> Void)) {
        var called = false
        let reply: ((HelperStatus) -> Void) = {
            status in
            if called { return }
            called = true
            callback(status)
        }

        let helperURL = Bundle.main.bundleURL.appendingPathComponent("Contents/Library/LaunchServices/" + PrivilegedHelperManager.machServiceName)
        guard
            CFBundleCopyInfoDictionaryForURL(helperURL as CFURL) != nil else {
            reply(.noFound)
            return
        }
        
        let helperFileExists = FileManager.default.fileExists(atPath: "/Library/PrivilegedHelperTools/\(PrivilegedHelperManager.machServiceName)")
        if !helperFileExists {
            reply(.noFound)
            return
        }
        
        if let currentBuild = Bundle.main.infoDictionary?["CFBundleVersion"] as? String,
           let installedBuild = UserDefaults.standard.string(forKey: "InstalledHelperBuild"),
           currentBuild != installedBuild {
            reply(.needUpdate)
            return
        }

        reply(.installed)
    }

    static var getHelperStatus: Bool {
        if let currentBuild = Bundle.main.infoDictionary?["CFBundleVersion"] as? String,
           let installedBuild = UserDefaults.standard.string(forKey: "InstalledHelperBuild"),
           currentBuild != installedBuild {
            return false
        }
        
        let helperURL = Bundle.main.bundleURL.appendingPathComponent("Contents/Library/LaunchServices/" + machServiceName)
        guard CFBundleCopyInfoDictionaryForURL(helperURL as CFURL) != nil else { return false }
        return FileManager.default.fileExists(atPath: "/Library/PrivilegedHelperTools/\(machServiceName)")
    }
    
    func reinstallHelper(completion: @escaping (Bool, String) -> Void) {
        disconnectHelper()

        removeInstallHelper()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else { return }

            let result = self.installHelperDaemon()
            
            switch result {
            case .success:
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                    guard let self = self else { return }

                    self.tryConnect(retryCount: 5, delay: 2.0, completion: completion)
                }
                
            case .authorizationFail:
                completion(false, String(localized: "获取授权失败"))
            case .getAdminFail:
                completion(false, String(localized: "获取管理员权限失败"))
            case .blessError(_):
                completion(false, String(localized: "安装失败: \(result.alertContent)"))
            }
        }
    }
    
    private func tryConnect(retryCount: Int, delay: TimeInterval = 2.0, completion: @escaping (Bool, String) -> Void) {
        guard retryCount > 0 else {
            completion(false, String(localized: "多次尝试连接失败"))
            return
        }
        
        guard let connection = connectToHelper() else {
            print("连接尝试失败，剩余重试次数: \(retryCount - 1)")
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.tryConnect(retryCount: retryCount - 1, delay: delay, completion: completion)
            }
            return
        }
        
        guard let helper = connection.remoteObjectProxy as? HelperToolProtocol else {
            completion(false, String(localized: "无法获取Helper代理"))
            return
        }
        
        helper.executeCommand(type: .shellCommand, path1: "whoami", path2: "", permissions: 0) { result in
            if result.contains("root") {
                completion(true, String(localized: "Helper 重新安装成功"))
            } else {
                completion(false, String(localized: "Helper 安装失败"))
            }
        }
    }

    func removeInstallHelper() {
        try? FileManager.default.removeItem(atPath: "/Library/PrivilegedHelperTools/\(PrivilegedHelperManager.machServiceName)")
        try? FileManager.default.removeItem(atPath: "/Library/LaunchDaemons/\(PrivilegedHelperManager.machServiceName).plist")
    }

    func connectToHelper() -> NSXPCConnection? {
        return connectionQueue.sync {
            createConnection()
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
        
        let newConnection = NSXPCConnection(machServiceName: PrivilegedHelperManager.machServiceName, 
                                          options: .privileged)

        let interface = NSXPCInterface(with: HelperToolProtocol.self)
        interface.setClasses(NSSet(array: [NSString.self, NSNumber.self]) as! Set<AnyHashable>,
                           for: #selector(HelperToolProtocol.executeCommand(type:path1:path2:permissions:withReply:)),
                           argumentIndex: 1,
                           ofReply: false)
        newConnection.remoteObjectInterface = interface

        newConnection.interruptionHandler = { [weak self] in
            DispatchQueue.main.async {
                self?.connectionState = .disconnected
                self?.connection = nil
            }
        }
        
        newConnection.invalidationHandler = { [weak self] in
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
                if result.contains("root") {
                    isConnected = true
                    DispatchQueue.main.async {
                        self?.connection = newConnection
                        self?.connectionState = .connected
                    }
                }
                semaphore.signal()
            }
            
            _ = semaphore.wait(timeout: .now() + 1.0)
        }
        
        if !isConnected {
            newConnection.invalidate()
            DispatchQueue.main.async {
                self.connectionState = .disconnected
            }
            return nil
        }
        
        return newConnection
    }

    func executeCommand(_ command: String, completion: @escaping (String) -> Void) {
        do {
            let helper = try getHelperProxy()
            
            if command.contains("perl") || command.contains("codesign") || command.contains("xattr") {
                helper.executeCommand(type: .shellCommand, path1: command, path2: "", permissions: 0) { [weak self] result in
                    DispatchQueue.main.async {
                        if result.starts(with: "Error:") {
                            self?.connectionState = .disconnected
                        } else {
                            self?.connectionState = .connected
                        }
                        completion(result)
                    }
                }
                return
            }
            
            let (type, path1, path2, permissions) = parseCommand(command)
            
            helper.executeCommand(type: type, path1: path1, path2: path2, permissions: permissions) { [weak self] result in
                DispatchQueue.main.async {
                    if result.starts(with: "Error:") {
                        self?.connectionState = .disconnected
                    } else {
                        self?.connectionState = .connected
                    }
                    completion(result)
                }
            }
        } catch {
            connectionState = .disconnected
            completion("Error: \(error.localizedDescription)")
        }
    }
    
    private func parseCommand(_ command: String) -> (CommandType, String, String, Int) {
        let components = command.components(separatedBy: " ")
        
        if command.hasPrefix("installer -pkg") {
            return (.install, components[2].replacingOccurrences(of: "\"", with: ""), "", 0)
        } else if command.hasPrefix("rm -rf") {
            return (.uninstall, components[2].replacingOccurrences(of: "\"", with: ""), "", 0)
        } else if command.hasPrefix("mv") || command.hasPrefix("cp") {
            return (.moveFile, 
                   components[1].replacingOccurrences(of: "\"", with: "").replacingOccurrences(of: "'", with: ""),
                   components[2].replacingOccurrences(of: "\"", with: "").replacingOccurrences(of: "'", with: ""),
                   0)
        } else if command.hasPrefix("chmod") {
            return (.setPermissions,
                   components[2].replacingOccurrences(of: "\"", with: ""),
                   "",
                   Int(components[1]) ?? 0)
        }
        
        return (.shellCommand, command, "", 0)
    }

    func reconnectHelper(completion: @escaping (Bool, String) -> Void) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            self.connectionState = .disconnected
            self.connection?.invalidate()
            self.connection = nil

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                do {
                    let helper = try self.getHelperProxy()

                    helper.executeCommand(type: .install, path1: "whoami", path2: "", permissions: 0) { result in
                        DispatchQueue.main.async {
                            if result == "root" {
                                self.connectionState = .connected
                                completion(true, String(localized: "Helper 重新连接成功"))
                            } else {
                                self.connectionState = .disconnected
                                completion(false, String(localized: "Helper 响应异常: \(result)"))
                            }
                        }
                    }
                } catch HelperError.connectionFailed {
                    completion(false, String(localized: "无法连接到 Helper"))
                } catch HelperError.proxyError {
                    completion(false, String(localized: "无法获取 Helper 代理"))
                } catch {
                    completion(false, String(localized: "连接出现错误: \(error.localizedDescription)"))
                }
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

    func forceReinstallHelper() {
        guard !isInitializing else { return }
        isInitializing = true
        
        removeInstallHelper()
        notifyInstall()
        
        isInitializing = false
    }

    func disconnectHelper() {
        connectionQueue.sync {
            if let existingConnection = connection {
                existingConnection.invalidate()
            }
            connection = nil
            connectionState = .disconnected
        }
    }
}

extension PrivilegedHelperManager {
    private func notifyInstall() {
        guard !isInitializing else { return }

        let result = installHelperDaemon()
        if case .success = result {
            checkInstall()
            return
        }
        result.alertAction()
        let ret = result.shouldRetryLegacyWay()
        useLegacyInstall = ret.0
        let isCancle = ret.1
        if !isCancle, useLegacyInstall  {
            checkInstall()
        } else if isCancle, !useLegacyInstall {
            NSAlert.alert(with: String(localized: "获取管理员授权失败，用户主动取消授权！"))
        }
    }
}

private enum DaemonInstallResult {
    case success
    case authorizationFail
    case getAdminFail
    case blessError(Int)
    var alertContent: String {
        switch self {
        case .success:
            return ""
        case .authorizationFail: return "Failed to create authorization!"
        case .getAdminFail: return "The user actively cancels the authorization, Failed to get admin authorization! "
        case let .blessError(code):
            switch code {
            case kSMErrorInternalFailure: return "blessError: kSMErrorInternalFailure"
            case kSMErrorInvalidSignature: return "blessError: kSMErrorInvalidSignature"
            case kSMErrorAuthorizationFailure: return "blessError: kSMErrorAuthorizationFailure"
            case kSMErrorToolNotValid: return "blessError: kSMErrorToolNotValid"
            case kSMErrorJobNotFound: return "blessError: kSMErrorJobNotFound"
            case kSMErrorServiceUnavailable: return "blessError: kSMErrorServiceUnavailable"
            case kSMErrorJobMustBeEnabled: return "Adobe Downloader Helper is disabled by other process. Please run \"sudo launchctl enable system/\(PrivilegedHelperManager.machServiceName)\" in your terminal. The command has been copied to your pasteboard"
            case kSMErrorInvalidPlist: return "blessError: kSMErrorInvalidPlist"
            default:
                return "bless unknown error:\(code)"
            }
        }
    }

    func shouldRetryLegacyWay() -> (Bool, Bool) {
        switch self {
        case .success: return (false, false)
        case let .blessError(code):
            switch code {
            case kSMErrorJobMustBeEnabled:
                return (false, false)
            default:
                return (true, false)
            }
        case .authorizationFail:
            return (true, false)
        case .getAdminFail:
            return (false, true)
        }
    }

    func alertAction() {
        switch self {
        case let .blessError(code):
            switch code {
            case kSMErrorJobMustBeEnabled:
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString("sudo launchctl enable system/\(PrivilegedHelperManager.machServiceName)", forType: .string)
            default:
                break
            }
        default:
            break
        }
    }
}

extension NSAlert {
    static func alert(with text: String) {
        let alert = NSAlert()
        alert.messageText = text
        alert.alertStyle = .warning
        alert.addButton(withTitle: NSLocalizedString("OK", comment: ""))
        alert.runModal()
    }
}

extension PrivilegedHelperManager {
    private func setupAutoReconnect() {
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.connectionState == .disconnected {
                _ = self.connectToHelper()
            }
        }
    }
}

enum HelperError: LocalizedError {
    case connectionFailed
    case proxyError
    case authorizationFailed
    case installationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .connectionFailed:
            return "无法连接到 Helper"
        case .proxyError:
            return "无法获取 Helper 代理"
        case .authorizationFailed:
            return "获取授权失败"
        case .installationFailed(let reason):
            return "安装失败: \(reason)"
        }
    }
}

extension PrivilegedHelperManager {
    public func getHelperProxy() throws -> HelperToolProtocol {
        if connectionState != .connected {
            guard let newConnection = connectToHelper() else {
                throw HelperError.connectionFailed
            }
            connection = newConnection
        }
        
        guard let helper = connection?.remoteObjectProxyWithErrorHandler({ [weak self] error in
            self?.connectionState = .disconnected
        }) as? HelperToolProtocol else {
            throw HelperError.proxyError
        }
        
        return helper
    }
}

extension Notification.Name {
    static let NSXPCConnectionInvalid = Notification.Name("NSXPCConnectionInvalidNotification")
}
