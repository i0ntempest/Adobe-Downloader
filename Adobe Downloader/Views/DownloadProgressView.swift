//
//  Adobe Downloader
//
//  Created by X1a0He on 2024/10/30.
//
import SwiftUI

struct DownloadProgressView: View {
    @ObservedObject var task: NewDownloadTask
    let onCancel: () -> Void
    let onPause: () -> Void
    let onResume: () -> Void
    let onRetry: () -> Void
    let onRemove: () -> Void
    
    @State private var showInstallPrompt = false
    @State private var isInstalling = false
    @State private var isPackageListExpanded: Bool = false
    @State private var expandedProducts: Set<String> = []
    @State private var iconImage: NSImage? = nil
    @State private var showSetupProcessAlert = false
    @State private var showCommandLineInstall = false
    @State private var showCopiedAlert = false

    private var statusLabel: some View {
        Text(task.status.description)
            .font(.caption)
            .foregroundColor(.white)
            .padding(.vertical, 2)
            .padding(.horizontal, 6)
            .background(statusBackgroundColor)
            .cornerRadius(4)
    }
    
    private var statusColor: Color {
        switch task.status {
        case .downloading:
            return .white
        case .preparing:
            return .white
        case .completed:
            return .white
        case .failed:
            return .white
        case .paused:
            return .white
        case .waiting:
            return .white
        case .retrying:
            return .white
        }
    }
    
    private var statusBackgroundColor: Color {
        switch task.status {
        case .downloading:
            return Color.blue
        case .preparing:
            return Color.purple.opacity(0.8)
        case .completed:
            return Color.green.opacity(0.8)
        case .failed:
            return Color.red.opacity(0.8)
        case .paused:
            return Color.orange.opacity(0.8)
        case .waiting:
            return Color.gray.opacity(0.8)
        case .retrying:
            return Color.yellow.opacity(0.8)
        }
    }
    
    private var actionButtons: some View {
        HStack(spacing: 8) {
            switch task.status {
            case .downloading, .preparing, .waiting:
                Button(action: onPause) {
                    Label("暂停", systemImage: "pause.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
                .controlSize(.regular)
                
                Button(action: onCancel) {
                    Label("取消", systemImage: "xmark")
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .controlSize(.regular)
                
            case .paused:
                Button(action: onResume) {
                    Label("继续", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .controlSize(.regular)
                
                Button(action: onCancel) {
                    Label("取消", systemImage: "xmark")
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .controlSize(.regular)
                
            case .failed(let info):
                if info.recoverable {
                    Button(action: onRetry) {
                        Label("重试", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    .controlSize(.regular)
                }
                
                Button(action: onRemove) {
                    Label("移除", systemImage: "xmark")
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .controlSize(.regular)
                
            case .completed:
                HStack(spacing: 8) {
                    if task.displayInstallButton {
                        Button(action: { 
                            #if DEBUG
                            do {
                                _ = try PrivilegedHelperManager.shared.getHelperProxy()
                                showInstallPrompt = false
                                isInstalling = true
                                Task {
                                    await globalNetworkManager.installProduct(at: task.directory)
                                }
                            } catch {
                                showSetupProcessAlert = true
                            }
                            #else
                            if !ModifySetup.isSetupModified() {
                                showSetupProcessAlert = true
                            } else {
                                do {
                                    _ = try PrivilegedHelperManager.shared.getHelperProxy()
                                    showInstallPrompt = false
                                    isInstalling = true
                                    Task {
                                        await globalNetworkManager.installProduct(at: task.directory)
                                    }
                                } catch {
                                    showSetupProcessAlert = true
                                }
                            }
                            #endif
                        }) {
                            Label("安装", systemImage: "square.and.arrow.down.on.square")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                        .controlSize(.regular)
                        .alert("Setup 组件未处理", isPresented: $showSetupProcessAlert) {
                            Button("确定") { }
                        } message: {
                            if !ModifySetup.isSetupModified() {
                                Text("未对 Setup 组件进行处理或者 Setup 组件不存在，无法使用安装功能\n你可以通过设置页面再次对 Setup 组件进行处理")
                                    .font(.system(size: 18))
                            } else {
                                Text("Helper 未安装或未连接，请先在设置中安装并连接 Helper")
                                    .font(.system(size: 18))
                            }
                        }
                    }
                    
                    Button(action: onRemove) {
                        Label("删除", systemImage: "trash")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .controlSize(.regular)
                }
                
            case .retrying:
                Button(action: onCancel) {
                    Label("取消", systemImage: "xmark")
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .controlSize(.regular)
            }
        }
        .controlSize(.small)
        .sheet(isPresented: $showInstallPrompt) {
            if task.displayInstallButton {
                VStack(spacing: 20) {
                    Text("是否要安装 \(task.displayName)?")
                        .font(.headline)
                    
                    HStack(spacing: 16) {
                        Button("取消") {
                            showInstallPrompt = false
                        }
                        .buttonStyle(.bordered)
                        
                        Button("安装") {
                            showInstallPrompt = false
                            isInstalling = true
                            Task {
                                await globalNetworkManager.installProduct(at: task.directory)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding()
                .frame(width: 300)
            }
        }
        .sheet(isPresented: $isInstalling) {
            Group {
                if case .installing(let progress, let status) = globalNetworkManager.installationState {
                    InstallProgressView(
                        productName: task.displayName,
                        progress: progress,
                        status: status,
                        onCancel: {
                            globalNetworkManager.cancelInstallation()
                            isInstalling = false
                        },
                        onRetry: nil
                    )
                } else if case .completed = globalNetworkManager.installationState {
                    InstallProgressView(
                        productName: task.displayName,
                        progress: 1.0,
                        status: String(localized: "安装完成"),
                        onCancel: {
                            isInstalling = false
                        },
                        onRetry: nil
                    )
                } else if case .failed(let error) = globalNetworkManager.installationState {
                    InstallProgressView(
                        productName: task.displayName,
                        progress: 0,
                        status: String(localized: "安装失败: \(error.localizedDescription)"),
                        onCancel: {
                            isInstalling = false
                        },
                        onRetry: {
                            Task {
                                await globalNetworkManager.retryInstallation(at: task.directory)
                            }
                        }
                    )
                } else {
                    InstallProgressView(
                        productName: task.displayName,
                        progress: 0,
                        status: String(localized: "准备安装..."),
                        onCancel: {
                            globalNetworkManager.cancelInstallation()
                            isInstalling = false
                        },
                        onRetry: nil
                    )
                }
            }
            .frame(minWidth: 400, minHeight: 200)
            .background(Color(NSColor.windowBackgroundColor))
        }
    }
    
    private func formatFileSize(_ size: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
    
    private func formatSpeed(_ bytesPerSecond: Double) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.includesUnit = true
        formatter.isAdaptive = true
        return formatter.string(fromByteCount: Int64(bytesPerSecond)) + "/s"
    }

    private func openInFinder(_ path: String) {
        NSWorkspace.shared.selectFile(URL(fileURLWithPath: path).path, inFileViewerRootedAtPath: URL(fileURLWithPath: path).deletingLastPathComponent().path)
    }
    
    private func formatRemainingTime(totalSize: Int64, downloadedSize: Int64, speed: Double) -> String {
        guard speed > 0 else { return "" }
        
        let remainingBytes = Double(totalSize - downloadedSize)
        let remainingSeconds = Int(remainingBytes / speed)
        
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func loadIcon() {
        let product = findProduct(id: task.productId)
        if product != nil {
            if let bestIcon = product?.getBestIcon(),
               let iconURL = URL(string: bestIcon.value) {

                if let cachedImage = IconCache.shared.getIcon(for: bestIcon.value) {
                    self.iconImage = cachedImage
                    return
                }
                
                Task {
                    do {
                        var request = URLRequest(url: iconURL)
                        request.timeoutInterval = 10
                        
                        let (data, response) = try await URLSession.shared.data(for: request)
                        
                        guard let httpResponse = response as? HTTPURLResponse,
                              (200...299).contains(httpResponse.statusCode),
                              let image = NSImage(data: data) else {
                            throw URLError(.badServerResponse)
                        }
                        
                        IconCache.shared.setIcon(image, for: bestIcon.value)

                        await MainActor.run {
                            self.iconImage = image
                        }
                    } catch {
                        if let localImage = NSImage(named: task.productId) {
                            await MainActor.run {
                                self.iconImage = localImage
                            }
                        }
                    }
                }
            } else if let localImage = NSImage(named: task.productId) {
                self.iconImage = localImage
            }
        }
    }

    private func formatPath(_ path: String) -> String {
        let url = URL(fileURLWithPath: path)
        let components = url.pathComponents
        
        if components.count <= 4 {
            return path
        }

        let lastComponents = components.suffix(2)
        return "/" + lastComponents.joined(separator: "/")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TaskHeaderView(iconImage: iconImage, task: task, loadIcon: loadIcon, formatPath: formatPath, openInFinder: openInFinder)

            TaskProgressView(task: task, formatRemainingTime: formatRemainingTime, formatSpeed: formatSpeed)

            if !task.dependenciesToDownload.isEmpty {
                Divider()
                PackageListView(
                    task: task,
                    isPackageListExpanded: $isPackageListExpanded,
                    showCommandLineInstall: $showCommandLineInstall,
                    showCopiedAlert: $showCopiedAlert,
                    expandedProducts: $expandedProducts,
                    actionButtons: AnyView(actionButtons)
                )
            }
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: Color.primary.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

private struct TaskHeaderView: View {
    let iconImage: NSImage?
    let task: NewDownloadTask
    let loadIcon: () -> Void
    let formatPath: (String) -> String
    let openInFinder: (String) -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Group {
                if let iconImage = iconImage {
                    Image(nsImage: iconImage)
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fit)
                } else {
                    Image(systemName: "app.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 32, height: 32)
            .onAppear(perform: loadIcon)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Text(task.displayName)
                            .font(.headline)
                        Text(task.productVersion)
                            .foregroundColor(.secondary)
                    }
                    
                    statusLabel
                    
                    Spacer()
                }
                
                Text(formatPath(task.directory.path))
                    .font(.caption)
                    .foregroundColor(.blue)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .onTapGesture {
                        openInFinder(task.directory.path)
                    }
                    .help(task.directory.path)
            }
        }
    }
    
    private var statusLabel: some View {
        Text(task.status.description)
            .font(.caption)
            .foregroundColor(.white)
            .padding(.vertical, 2)
            .padding(.horizontal, 6)
            .background(statusBackgroundColor)
            .cornerRadius(4)
    }
    
    private var statusBackgroundColor: Color {
        switch task.status {
        case .downloading:
            return Color.blue
        case .preparing:
            return Color.purple.opacity(0.8)
        case .completed:
            return Color.green.opacity(0.8)
        case .failed:
            return Color.red.opacity(0.8)
        case .paused:
            return Color.orange.opacity(0.8)
        case .waiting:
            return Color.gray.opacity(0.8)
        case .retrying:
            return Color.yellow.opacity(0.8)
        }
    }
}

private struct TaskProgressView: View {
    let task: NewDownloadTask
    let formatRemainingTime: (Int64, Int64, Double) -> String
    let formatSpeed: (Double) -> String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                HStack(spacing: 4) {
                    Text(task.formattedDownloadedSize)
                    Text("/")
                    Text(task.formattedTotalSize)
                }
                
                Spacer()
                
                if task.totalSpeed > 0 {
                    Text(formatRemainingTime(
                        task.totalSize,
                        task.totalDownloadedSize,
                        task.totalSpeed
                    ))
                    .foregroundColor(.secondary)
                }
                
                Text("\(Int(task.totalProgress * 100))%")
                
                if task.totalSpeed > 0 {
                    Text(formatSpeed(task.totalSpeed))
                        .foregroundColor(.secondary)
                }
            }
            .font(.caption)
            
            ProgressView(value: task.totalProgress)
                .progressViewStyle(.linear)
        }
    }
}

private struct PackageListView: View {
    let task: NewDownloadTask
    @Binding var isPackageListExpanded: Bool
    @Binding var showCommandLineInstall: Bool
    @Binding var showCopiedAlert: Bool
    @Binding var expandedProducts: Set<String>
    let actionButtons: AnyView
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Button(action: { 
                    withAnimation {
                        isPackageListExpanded.toggle()
                    }
                }) {
                    HStack {
                        Image(systemName: isPackageListExpanded ? "chevron.down" : "chevron.right")
                            .foregroundColor(.secondary)
                        Text("产品和包列表")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                #if DEBUG
                Button(action: {
                    let containerURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                    let tasksDirectory = containerURL.appendingPathComponent("Adobe Downloader/tasks", isDirectory: true)
                    let fileName = "\(task.productId == "APRO" ? "Adobe Downloader \(task.productId)_\(task.productVersion)_\(task.platform)" : "Adobe Downloader \(task.productId)_\(task.productVersion)-\(task.language)-\(task.platform)")-task.json"
                    let fileURL = tasksDirectory.appendingPathComponent(fileName)
                    NSWorkspace.shared.selectFile(fileURL.path, inFileViewerRootedAtPath: tasksDirectory.path)
                }) {
                    Label("查看持久化文件", systemImage: "doc.text.magnifyingglass")
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .controlSize(.regular)
                #endif

                if case .completed = task.status, task.productId != "APRO" {
                    CommandLineInstallButton(
                        task: task,
                        showCommandLineInstall: $showCommandLineInstall,
                        showCopiedAlert: $showCopiedAlert
                    )
                }
                
                actionButtons
            }
            
            if isPackageListExpanded {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(task.dependenciesToDownload, id: \.sapCode) { product in
                            ProductRow(
                                product: product,
                                isCurrentProduct: task.currentPackage?.id == product.packages.first?.id,
                                expandedProducts: $expandedProducts
                            )
                        }
                    }
                }
                .frame(maxHeight: 200)
            }
        }
    }
}

private struct CommandLineInstallButton: View {
    let task: NewDownloadTask
    @Binding var showCommandLineInstall: Bool
    @Binding var showCopiedAlert: Bool
    
    var body: some View {
        Button(action: {
            showCommandLineInstall.toggle()
        }) {
            Label("命令行安装", systemImage: "terminal")
        }
        .buttonStyle(.borderedProminent)
        .tint(.purple)
        .controlSize(.regular)
        .popover(isPresented: $showCommandLineInstall, arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 8) {
                Button("复制命令") {
                    let setupPath = "/Library/Application Support/Adobe/Adobe Desktop Common/HDBox/Setup"
                    let driverPath = "\(task.directory.path)/driver.xml"
                    let command = "sudo \"\(setupPath)\" --install=1 --driverXML=\"\(driverPath)\""
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(command, forType: .string)
                    showCopiedAlert = true
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        showCopiedAlert = false
                    }
                }

                if showCopiedAlert {
                    Text("已复制")
                        .font(.caption)
                        .foregroundColor(.green)
                }

                let setupPath = "/Library/Application Support/Adobe/Adobe Desktop Common/HDBox/Setup"
                let driverPath = "\(task.directory.path)/driver.xml"
                let command = "sudo \"\(setupPath)\" --install=1 --driverXML=\"\(driverPath)\""
                Text(command)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.secondary)
                    .textSelection(.enabled)
                    .padding(8)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(6)
            }
            .padding()
            .frame(width: 400)
        }
    }
}

struct ProductRow: View {
    @ObservedObject var product: DependenciesToDownload
    let isCurrentProduct: Bool
    @Binding var expandedProducts: Set<String>
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button(action: {
                withAnimation {
                    if expandedProducts.contains(product.sapCode) {
                        expandedProducts.remove(product.sapCode)
                    } else {
                        expandedProducts.insert(product.sapCode)
                    }
                }
            }) {
                HStack {
                    Image(systemName: "cube.box")
                        .foregroundColor(.blue)
                    Text("\(product.sapCode) \(product.version)\(product.sapCode != "APRO" ? " - (\(product.buildGuid))" : "")")
                        .font(.caption)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text("\(product.completedPackages)/\(product.totalPackages)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Image(systemName: expandedProducts.contains(product.sapCode) ? "chevron.down" : "chevron.right")
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
                .padding(.horizontal)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            
            if expandedProducts.contains(product.sapCode) {
                VStack(spacing: 8) {
                    ForEach(product.packages) { package in
                        PackageRow(package: package)
                            .padding(.horizontal)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(8)
                    }
                }
                .padding(.leading, 24)
            }
        }
    }
}

struct PackageRow: View {
    @ObservedObject var package: Package
    
    private func statusView() -> some View {
        Group {
            switch package.status {
            case .waiting:
                HStack {
                    Image(systemName: "hourglass.circle.fill")
                    Text(package.status.description)
                }
                .foregroundColor(.secondary)
            case .downloading:
                HStack {
                    Text("\(Int(package.progress * 100))%")
                }
                .foregroundColor(.blue)
            case .completed:
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text(package.status.description)
                }
                .foregroundColor(.green)
            default:
                HStack {
                    Text(package.status.description)
                }
                .foregroundColor(.secondary)
            }
        }
    }
    
    private func formatSpeed(_ bytesPerSecond: Double) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.includesUnit = true
        formatter.isAdaptive = true
        return formatter.string(fromByteCount: Int64(bytesPerSecond)) + "/s"
    }
    
    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text("\(package.fullPackageName) (\(package.packageVersion))")
                    .font(.caption)
                    .foregroundColor(.primary)
                
                HStack(spacing: 4) {
                    Text(package.type)
                        .font(.caption2)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(2)

                    Text(package.formattedSize)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                statusView()
                    .font(.caption)
            }

            if package.status == .downloading {
                VStack() {
                    ProgressView(value: package.progress)
                        .progressViewStyle(.linear)
                    
                    HStack {
                        Text("\(package.formattedDownloadedSize) / \(package.formattedSize)")
                        Spacer()
                        if package.speed > 0 {
                            Text(formatSpeed(package.speed))
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 10)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(6)
    }
}
