//
//  HelperMigrationManager.swift
//  Adobe Downloader
//
//  Created by X1a0He on 2025/07/20.
//

import Foundation
import ServiceManagement
import os.log

class HelperMigrationManager {
    
    private let logger = Logger(subsystem: "com.x1a0he.macOS.Adobe-Downloader", category: "Migration")

    static func performMigrationIfNeeded() async throws {
        let migrationManager = HelperMigrationManager()
        
        if migrationManager.needsMigration() {
            try await migrationManager.performMigration()
        }
    }

    private func needsMigration() -> Bool {
        // 检查是否存在旧的 SMJobBless 安装
        let legacyPlistPath = "/Library/LaunchDaemons/com.x1a0he.macOS.Adobe-Downloader.helper.plist"
        let legacyHelperPath = "/Library/PrivilegedHelperTools/com.x1a0he.macOS.Adobe-Downloader.helper"
        
        let hasLegacyFiles = FileManager.default.fileExists(atPath: legacyPlistPath) ||
                            FileManager.default.fileExists(atPath: legacyHelperPath)

        let appService = SMAppService.daemon(plistName: "com.x1a0he.macOS.Adobe-Downloader.helper")
        let hasModernService = appService.status != .notRegistered
        
        logger.info("迁移检查 - 旧文件存在: \(hasLegacyFiles), 新服务已注册: \(hasModernService)")
        
        return hasLegacyFiles && !hasModernService
    }

    private func performMigration() async throws {
        logger.info("开始 Helper 迁移过程")

        try await stopLegacyService()

        try await cleanupLegacyFiles()

        try await registerModernService()

        try await validateNewService()
        
        logger.info("Helper 迁移完成")
    }

    private func stopLegacyService() async throws {
        logger.info("停止旧的 Helper 服务")
        
        let script = """
        #!/bin/bash
        # 停止旧的 LaunchDaemon
        sudo /bin/launchctl unload /Library/LaunchDaemons/com.x1a0he.macOS.Adobe-Downloader.helper.plist 2>/dev/null || true
        
        # 终止可能运行的进程
        sudo /usr/bin/killall -u root -9 com.x1a0he.macOS.Adobe-Downloader.helper 2>/dev/null || true
        
        exit 0
        """
        
        try await executePrivilegedScript(script, description: "停止旧服务")
    }

    private func cleanupLegacyFiles() async throws {
        logger.info("清理旧的安装文件")
        
        let script = """
        #!/bin/bash
        # 删除旧的 plist 文件
        sudo /bin/rm -f /Library/LaunchDaemons/com.x1a0he.macOS.Adobe-Downloader.helper.plist
        
        # 删除旧的 Helper 文件
        sudo /bin/rm -f /Library/PrivilegedHelperTools/com.x1a0he.macOS.Adobe-Downloader.helper
        
        exit 0
        """
        
        try await executePrivilegedScript(script, description: "清理旧文件")
    }

    private func registerModernService() async throws {
        logger.info("注册新的 SMAppService")
        
        let modernManager = ModernPrivilegedHelperManager.shared
        await modernManager.checkAndInstallHelper()

        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
    }

    private func validateNewService() async throws {
        logger.info("验证新服务")
        
        let modernManager = ModernPrivilegedHelperManager.shared
        let status = await modernManager.getHelperStatus()
        
        switch status {
        case .installed:
            logger.info("新服务验证成功")
        case .needsApproval:
            logger.warning("新服务需要用户批准")
            throw MigrationError.requiresUserApproval
        default:
            logger.error("新服务验证失败: \(String(describing: status))")
            throw MigrationError.validationFailed
        }
    }

    private func executePrivilegedScript(_ script: String, description: String) async throws {
        let tempDir = FileManager.default.temporaryDirectory
        let scriptURL = tempDir.appendingPathComponent("migration_\(UUID().uuidString).sh")
        
        try script.write(to: scriptURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)
        
        defer {
            try? FileManager.default.removeItem(at: scriptURL)
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            task.arguments = ["-e", "do shell script \"\(scriptURL.path)\" with administrator privileges"]
            
            do {
                try task.run()
                task.waitUntilExit()
                
                if task.terminationStatus == 0 {
                    self.logger.info("\(description) 执行成功")
                    continuation.resume()
                } else {
                    self.logger.error("\(description) 执行失败: \(task.terminationStatus)")
                    continuation.resume(throwing: MigrationError.scriptExecutionFailed(description))
                }
            } catch {
                self.logger.error("\(description) 启动失败: \(error)")
                continuation.resume(throwing: error)
            }
        }
    }
}

enum MigrationError: LocalizedError {
    case requiresUserApproval
    case validationFailed
    case scriptExecutionFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .requiresUserApproval:
            return String(localized: "迁移完成，但需要在系统设置中批准新的 Helper 服务")
        case .validationFailed:
            return String(localized: "新 Helper 服务验证失败")
        case .scriptExecutionFailed(let description):
            return String(localized: "\(description) 执行失败")
        }
    }
}

extension ModernPrivilegedHelperManager {
    static func initializeWithMigration() async throws -> ModernPrivilegedHelperManager {
        try await HelperMigrationManager.performMigrationIfNeeded()
        
        let manager = ModernPrivilegedHelperManager.shared
        await manager.checkAndInstallHelper()
        
        return manager
    }
}
