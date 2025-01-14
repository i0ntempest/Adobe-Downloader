import Foundation
import os.log

@objc enum CommandType: Int {
    case install
    case uninstall
    case moveFile
    case setPermissions
    case shellCommand
}

class SecureCommandHandler {
    static func createCommand(type: CommandType, path1: String, path2: String = "", permissions: Int = 0) -> String? {
        if type == .shellCommand {
            return path1
        }
        
        if type != .shellCommand {
            if !validatePath(path1) || (!path2.isEmpty && !validatePath(path2)) {
                return nil
            }
        }
        
        switch type {
        case .install:
            return "installer -pkg \"\(path1)\" -target /"
        case .uninstall:
            return "rm -rf \"\(path1)\""
        case .moveFile:
            return "cp \"\(path1)\" \"\(path2)\""
        case .setPermissions:
            return "chmod \(permissions) \"\(path1)\""
        case .shellCommand:
            return path1
        }
    }
    
    static func validatePath(_ path: String) -> Bool {
        let allowedPaths = ["/Library/Application Support/Adobe"]
        if allowedPaths.contains(where: { path.hasPrefix($0) }) {
            return true
        }
        
        let forbiddenPaths = ["/System", "/usr", "/bin", "/sbin", "/var"]
        return !forbiddenPaths.contains { path.hasPrefix($0) }
    }
}

@objc(HelperToolProtocol) protocol HelperToolProtocol {
    @objc(executeCommand:path1:path2:permissions:withReply:)
    func executeCommand(type: CommandType, path1: String, path2: String, permissions: Int, withReply reply: @escaping (String) -> Void)
    func getInstallationOutput(withReply reply: @escaping (String) -> Void)
}

class HelperTool: NSObject, HelperToolProtocol {
    private let listener: NSXPCListener
    private var connections: Set<NSXPCConnection> = []
    private var currentTask: Process?
    private var outputPipe: Pipe?
    private var outputBuffer: String = ""
    private let logger = Logger(subsystem: "com.x1a0he.macOS.Adobe-Downloader.helper", category: "Helper")
    private let operationQueue = DispatchQueue(label: "com.x1a0he.macOS.Adobe-Downloader.helper.operation")

    override init() {
        listener = NSXPCListener(machServiceName: "com.x1a0he.macOS.Adobe-Downloader.helper")
        super.init()
        listener.delegate = self
        logger.notice("HelperTool 初始化完成")
    }
    
    func run() {
        logger.notice("Helper 服务开始运行")
        ProcessInfo.processInfo.disableSuddenTermination()
        ProcessInfo.processInfo.disableAutomaticTermination("Helper is running")

        listener.resume()
        logger.notice("XPC Listener 已启动")

        RunLoop.current.run()
    }

    func executeCommand(type: CommandType, path1: String, path2: String, permissions: Int, withReply reply: @escaping (String) -> Void) {
        operationQueue.async {
            self.logger.notice("收到安全命令执行请求")
            
            guard let shellCommand = SecureCommandHandler.createCommand(type: type, path1: path1, path2: path2, permissions: permissions) else {
                self.logger.error("不安全的路径访问被拒绝")
                reply("Error: Invalid path access")
                return
            }
            
            let isSetupCommand = shellCommand.contains("Setup") && shellCommand.contains("--install")
            
            let task = Process()
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            
            task.standardOutput = outputPipe
            task.standardError = errorPipe
            task.arguments = ["-c", shellCommand]
            task.executableURL = URL(fileURLWithPath: "/bin/sh")
            
            if isSetupCommand {
                self.currentTask = task
                self.outputPipe = outputPipe
                self.outputBuffer = ""
                
                let outputHandle = outputPipe.fileHandleForReading
                outputHandle.readabilityHandler = { [weak self] handle in
                    guard let self = self else { return }
                    let data = handle.availableData
                    if let output = String(data: data, encoding: .utf8) {
                        self.outputBuffer += output
                    }
                }
                
                do {
                    try task.run()
                    self.logger.debug("Setup命令开始执行")
                    reply("Started")
                } catch {
                    let errorMsg = "Error: \(error.localizedDescription)"
                    self.logger.error("执行失败: \(errorMsg, privacy: .public)")
                    reply(errorMsg)
                }
                return
            }
            
            do {
                try task.run()
                self.logger.debug("安全命令开始执行")
            } catch {
                let errorMsg = "Error: \(error.localizedDescription)"
                self.logger.error("执行失败: \(errorMsg, privacy: .public)")
                reply(errorMsg)
                return
            }

            let outputHandle = outputPipe.fileHandleForReading
            var output = ""
            
            outputHandle.readabilityHandler = { handle in
                let data = handle.availableData
                if let newOutput = String(data: data, encoding: .utf8) {
                    output += newOutput
                }
            }

            task.waitUntilExit()
            
            outputHandle.readabilityHandler = nil
            errorPipe.fileHandleForReading.readabilityHandler = nil
            
            if task.terminationStatus == 0 {
                self.logger.notice("命令执行成功")
                reply(output.isEmpty ? "Success" : output)
            } else {
                self.logger.error("命令执行失败，退出码: \(task.terminationStatus, privacy: .public)")
                reply("Error: Command failed with exit code \(task.terminationStatus)")
            }
        }
    }
    
    func getInstallationOutput(withReply reply: @escaping (String) -> Void) {
        guard let task = currentTask else {
            reply("")
            return
        }
        
        if !task.isRunning {
            let exitCode = task.terminationStatus
            reply("Exit Code: \(exitCode)")
            cleanup()
            return
        }
        
        if !outputBuffer.isEmpty {
            let output = outputBuffer
            outputBuffer = ""
            reply(output)
        } else {
            reply("")
        }
    }

    func cleanup() {
        if let pipe = outputPipe {
            pipe.fileHandleForReading.readabilityHandler = nil
        }
        currentTask?.terminate()
        currentTask = nil
        outputPipe = nil
    }
}

extension HelperTool: NSXPCListenerDelegate {
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        logger.notice("收到新的XPC连接请求")
        
        let pid = newConnection.processIdentifier
        
        var codeRef: SecCode?
        let codeSigningResult = SecCodeCopyGuestWithAttributes(nil,
            [kSecGuestAttributePid: pid] as CFDictionary,
            [], &codeRef)
        
        guard codeSigningResult == errSecSuccess,
              let code = codeRef else {
            logger.error("代码签名验证失败: \(pid)")
            return false
        }
        
        var requirement: SecRequirement?
        let requirementString = "anchor apple generic and identifier \"com.x1a0he.macOS.Adobe-Downloader\""
        guard SecRequirementCreateWithString(requirementString as CFString,
                                           [], &requirement) == errSecSuccess,
              let req = requirement else {
            logger.error("签名要求创建失败")
            return false
        }
        
        let validityResult = SecCodeCheckValidity(code, [], req)
        if validityResult != errSecSuccess {
            logger.error("代码签名验证不匹配: \(validityResult)")
            return false
        }
        
        let interface = NSXPCInterface(with: HelperToolProtocol.self)
        
        interface.setClasses(NSSet(array: [NSString.self, NSNumber.self]) as! Set<AnyHashable>,
                           for: #selector(HelperToolProtocol.executeCommand(type:path1:path2:permissions:withReply:)),
                           argumentIndex: 1,
                           ofReply: false)
        
        newConnection.exportedInterface = interface
        newConnection.exportedObject = self
        
        newConnection.invalidationHandler = { [weak self] in
            guard let self = self else { return }
            self.logger.notice("XPC连接已断开")
            self.connections.remove(newConnection)
            if self.connections.isEmpty {
                self.cleanup()
            }
        }
        
        newConnection.interruptionHandler = { [weak self] in
            guard let self = self else { return }
            self.logger.error("XPC连接中断")
            self.connections.remove(newConnection)
            if self.connections.isEmpty {
                self.cleanup()
            }
        }
        
        self.connections.insert(newConnection)
        newConnection.resume()
        logger.notice("新的XPC连接已成功建立，当前活动连接数: \(self.connections.count)")
        
        return true
    }
}

autoreleasepool {
    let helperTool = HelperTool()
    helperTool.run()
}
