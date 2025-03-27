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
    @State private var showDeleteConfirmation = false

    private var statusLabel: some View {
        Text(task.status.description)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(.white)
            .padding(.vertical, 3)
            .padding(.horizontal, 7)
            .background(statusBackgroundColor)
            .cornerRadius(5)
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
        HStack(spacing: 12) {
            switch task.status {
            case .downloading, .preparing, .waiting:
                Button(action: onPause) {
                    Label("暂停", systemImage: "pause.fill")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                }
                .buttonStyle(BeautifulButtonStyle(baseColor: .orange))
                
                Button(action: onCancel) {
                    Label("取消", systemImage: "xmark")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                }
                .buttonStyle(BeautifulButtonStyle(baseColor: .red))
                
            case .paused:
                Button(action: onResume) {
                    Label("继续", systemImage: "play.fill")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                }
                .buttonStyle(BeautifulButtonStyle(baseColor: .blue))
                
                Button(action: onCancel) {
                    Label("取消", systemImage: "xmark")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                }
                .buttonStyle(BeautifulButtonStyle(baseColor: .red))
                
            case .failed(let info):
                if info.recoverable {
                    Button(action: onRetry) {
                        Label("重试", systemImage: "arrow.clockwise")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white)
                    }
                    .buttonStyle(BeautifulButtonStyle(baseColor: .blue))
                }
                
                Button(action: { showDeleteConfirmation = true }) {
                    Label("移除", systemImage: "xmark")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                }
                .buttonStyle(BeautifulButtonStyle(baseColor: .red))
                
            case .completed:
                HStack(spacing: 12) {
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
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white)
                        }
                        .buttonStyle(BeautifulButtonStyle(baseColor: .green))
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
                    
                    Button(action: { showDeleteConfirmation = true }) {
                        Label("删除", systemImage: "trash")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white)
                    }
                    .buttonStyle(BeautifulButtonStyle(baseColor: .red))
                }
                
            case .retrying:
                Button(action: onCancel) {
                    Label("取消", systemImage: "xmark")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                }
                .buttonStyle(BeautifulButtonStyle(baseColor: .red))
            }
        }
        .alert("确认删除", isPresented: $showDeleteConfirmation) {
            Button("取消", role: .cancel) { }
            Button("删除", role: .destructive) {
                onRemove()
            }
        } message: {
            Text("确定要删除任务\(task.displayName)吗？")
        }
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
                } else if case .failed(let error, let errorDetails) = globalNetworkManager.installationState {
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
                        },
                        errorDetails: errorDetails
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
            .frame(minWidth: 700, minHeight: 200)
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
        HStack(spacing: 16) {
            Group {
                if let iconImage = iconImage {
                    Image(nsImage: iconImage)
                        .resizable()
                        .interpolation(.high)
                        .aspectRatio(contentMode: .fit)
                        .padding(4)
                } else {
                    Image(systemName: "app.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .foregroundColor(.secondary)
                        .padding(4)
                }
            }
            .frame(width: 42, height: 42)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            )
            .onAppear(perform: loadIcon)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    HStack(spacing: 6) {
                        Text(task.displayName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Text(task.productVersion)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(4)
                    }

                    statusLabel
                    
                    Spacer()
                }

                HStack(spacing: 4) {
                    Image(systemName: "folder")
                        .font(.system(size: 10))
                        .foregroundColor(.blue.opacity(0.8))
                    
                    Text(formatPath(task.directory.path))
                        .font(.system(size: 11))
                        .foregroundColor(.primary.opacity(0.7))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .padding(.vertical, 3)
                .padding(.horizontal, 6)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.blue.opacity(0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.blue.opacity(0.1), lineWidth: 0.5)
                )
                .onTapGesture {
                    openInFinder(task.directory.path)
                }
                .help(task.directory.path)
            }
        }
    }
    
    private var statusLabel: some View {
        Text(task.status.description)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(.white)
            .padding(.vertical, 3)
            .padding(.horizontal, 7)
            .background(statusBackgroundColor)
            .cornerRadius(5)
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
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                HStack(spacing: 4) {
                    Text(task.formattedDownloadedSize)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.primary.opacity(0.8))
                    Text("/")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary.opacity(0.6))
                    Text(task.formattedTotalSize)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 2)
                .padding(.horizontal, 6)
                .background(Color.secondary.opacity(0.08))
                .cornerRadius(4)
                
                Spacer()

                Text("\(Int(task.totalProgress * 100))%")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.blue)
                    .padding(.vertical, 2)
                    .padding(.horizontal, 8)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(4)
            }

            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 10))
                    if task.totalSpeed > 0 {
                        Text(formatRemainingTime(
                            task.totalSize,
                            task.totalDownloadedSize,
                            task.totalSpeed
                        ))
                        .font(.system(size: 11))
                        .transition(.opacity)
                    } else {
                        Text("--:--")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary.opacity(0.5))
                    }
                }
                .foregroundColor(.secondary)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down")
                        .font(.system(size: 10))
                    if task.totalSpeed > 0 {
                        Text(formatSpeed(task.totalSpeed))
                            .font(.system(size: 11))
                            .transition(.opacity)
                    } else {
                        Text("--")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary.opacity(0.5))
                    }
                }
                .foregroundColor(.secondary)
            }
            .padding(.horizontal, 2)
            .animation(.easeInOut(duration: 0.2), value: task.totalSpeed > 0)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.1))
                        .frame(height: 6)
                        .cornerRadius(3)

                    Rectangle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.blue.opacity(0.7), Color.blue]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(0, CGFloat(task.totalProgress) * geometry.size.width), height: 6)
                        .cornerRadius(3)
                        .animation(.linear(duration: 0.3), value: task.totalProgress)
                }
            }
            .frame(height: 6)
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
                    HStack(spacing: 4) {
                        Image(systemName: isPackageListExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Text("产品和包列表")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .contentShape(Rectangle())
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 5)
                            .fill(Color.secondary.opacity(0.08))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(Color.secondary.opacity(0.15), lineWidth: 0.5)
                    )
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
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                }
                .buttonStyle(BeautifulButtonStyle(baseColor: .blue))
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
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(task.dependenciesToDownload, id: \.sapCode) { product in
                            ProductRow(
                                product: product,
                                isCurrentProduct: task.currentPackage?.id == product.packages.first?.id,
                                expandedProducts: $expandedProducts
                            )
                            .shadow(color: Color.black.opacity(0.03), radius: 2, x: 0, y: 1)
                        }
                    }
                    .padding(.horizontal, 2)
                    .padding(.vertical, 5)
                }
                .frame(maxHeight: 300)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(NSColor.windowBackgroundColor).opacity(0.5))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.1), lineWidth: 0.5)
                )
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
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white)
        }
        .buttonStyle(BeautifulButtonStyle(baseColor: .purple))
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
                .buttonStyle(BeautifulButtonStyle(baseColor: .purple))
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .shadow(color: Color.purple.opacity(0.3), radius: 3, x: 0, y: 2)

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
    @State private var showCopiedAlert = false
    
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
                HStack(spacing: 8) {
                    Image(systemName: "cube.box.fill")
                        .font(.system(size: 13))
                        .foregroundColor(.blue.opacity(0.8))
                        
                    Text("\(product.sapCode) \(product.version)\(product.sapCode != "APRO" ? " - (\(product.buildGuid))" : "")")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.primary.opacity(0.8))
                        
                    if product.sapCode != "APRO" {
                        Button(action: {
                            let pasteboard = NSPasteboard.general
                            pasteboard.clearContents()
                            pasteboard.setString(product.buildGuid, forType: .string)
                            showCopiedAlert = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                showCopiedAlert = false
                            }
                        }) {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 10))
                                .foregroundColor(.white)
                        }
                        .buttonStyle(BeautifulButtonStyle(baseColor: .blue))
                        .help("复制 buildGuid")
                        .popover(isPresented: $showCopiedAlert, arrowEdge: .trailing) {
                            Text("已复制")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .cornerRadius(6)
                                .padding(6)
                        }
                    }

                    Spacer()
                    
                    Text("\(product.completedPackages)/\(product.totalPackages)")
                        .font(.system(size: 12))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.08))
                        .cornerRadius(4)
                        .foregroundColor(.primary.opacity(0.7))
                    
                    Image(systemName: expandedProducts.contains(product.sapCode) ? "chevron.down" : "chevron.right")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(NSColor.controlBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.1), lineWidth: 0.5)
                )
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
                HStack(spacing: 4) {
                    Image(systemName: "hourglass.circle.fill")
                        .font(.system(size: 10))
                    Text(package.status.description)
                        .font(.system(size: 11, weight: .medium))
                }
                .padding(.vertical, 3)
                .padding(.horizontal, 6)
                .background(Color.secondary.opacity(0.1))
                .foregroundColor(.secondary.opacity(0.8))
                .cornerRadius(4)
            case .downloading:
                HStack(spacing: 3) {
                    Text("\(Int(package.progress * 100))%")
                        .font(.system(size: 11, weight: .semibold))
                }
                .padding(.vertical, 3)
                .padding(.horizontal, 6)
                .background(Color.blue.opacity(0.1))
                .foregroundColor(.blue.opacity(0.9))
                .cornerRadius(4)
            case .completed:
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10))
                    Text(package.status.description)
                        .font(.system(size: 11, weight: .medium))
                }
                .padding(.vertical, 3)
                .padding(.horizontal, 6)
                .background(Color.green.opacity(0.1))
                .foregroundColor(.green.opacity(0.9))
                .cornerRadius(4)
            default:
                HStack(spacing: 4) {
                    Text(package.status.description)
                        .font(.system(size: 11, weight: .medium))
                }
                .padding(.vertical, 3)
                .padding(.horizontal, 6)
                .background(Color.secondary.opacity(0.1))
                .foregroundColor(.secondary.opacity(0.8))
                .cornerRadius(4)
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
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Text("\(package.fullPackageName) (\(package.packageVersion))")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary.opacity(0.8))
                
                HStack(spacing: 6) {
                    Text(package.type)
                        .font(.system(size: 10, weight: .medium))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.blue.opacity(0.1))
                        )
                        .foregroundColor(.blue.opacity(0.8))

                    Text(package.formattedSize)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary.opacity(0.8))
                }
                
                Spacer()
                
                statusView()
                    .font(.system(size: 11))
            }
            .padding(.vertical, 3)

            if package.status == .downloading {
                VStack(spacing: 6) {
                    ProgressView(value: package.progress)
                        .progressViewStyle(.linear)
                        .tint(Color.blue.opacity(0.8))
                        .animation(.easeInOut(duration: 0.3), value: package.progress)

                    HStack(spacing: 8) {
                        HStack(spacing: 4) {
                            Text("\(package.formattedDownloadedSize) / \(package.formattedSize)")
                                .font(.system(size: 11))
                                .foregroundColor(.primary.opacity(0.7))
                        }
                        .padding(.vertical, 2)
                        .padding(.horizontal, 6)
                        .background(Color.secondary.opacity(0.08))
                        .cornerRadius(4)
                        
                        Spacer()
                        
                        if package.speed > 0 {
                            HStack(spacing: 3) {
                                Image(systemName: "arrow.down")
                                    .font(.system(size: 9))
                                    .foregroundColor(.blue.opacity(0.7))
                                    
                                Text(formatSpeed(package.speed))
                                    .font(.system(size: 11))
                                    .foregroundColor(.blue.opacity(0.8))
                            }
                            .padding(.vertical, 2)
                            .padding(.horizontal, 6)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(4)
                        }
                    }
                }
                .padding(.horizontal, 2)
                .padding(.top, 4)
                .padding(.bottom, 2)
            }
        }
        .padding(.vertical, 10)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(6)
    }
}
