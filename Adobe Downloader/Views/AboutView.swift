//
//  Adobe Downloader
//
//  Created by X1a0He on 2024/10/30.
//

import SwiftUI
import Sparkle
import Combine


private enum AboutViewConstants {
    static let appIconSize: CGFloat = 96
    static let titleFontSize: CGFloat = 18
    static let subtitleFontSize: CGFloat = 14
    static let linkFontSize: CGFloat = 14
    static let licenseFontSize: CGFloat = 12

    static let verticalSpacing: CGFloat = 12
    static let formPadding: CGFloat = 8

    static let links: [(title: String, url: String)] = [
        ("@X1a0He", "https://t.me/X1a0He_bot"),
        ("Github: Adobe Downloader", "https://github.com/X1a0He/Adobe-Downloader"),
        ("QiuChenly: InjectLib", "https://github.com/QiuChenly/InjectLib")
    ]
}

struct ExternalLinkView: View {
    let title: String
    let url: String

    var body: some View {
        Link(title, destination: URL(string: url)!)
            .font(.system(size: AboutViewConstants.linkFontSize))
            .foregroundColor(.blue)
    }
}

struct AboutView: View {
    private let updater: SPUUpdater
    @State private var selectedTab = "general_settings"

    init(updater: SPUUpdater) {
        self.updater = updater
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralSettingsView(updater: updater)
                .tabItem {
                    Label("通用", systemImage: "gear")
                }
                .tag("general_settings")

            CleanupView()
                .tabItem {
                    Label("清理工具", systemImage: "trash")
                }
                .tag("cleanup_view")

            QAView()
                .tabItem {
                    Label("常见问题", systemImage: "questionmark.circle")
                }
                .tag("qa_view")

            AboutAppView()
                .tabItem {
                    Label("关于", systemImage: "info.circle")
                }
                .tag("about_app")
        }
        .background(Color(.clear))
        .frame(width: 600)
        .onAppear {
            selectedTab = "general_settings"
        }
    }
}

struct AboutAppView: View {
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }

    var body: some View {
        VStack(spacing: AboutViewConstants.verticalSpacing) {
            appIconSection
            appInfoSection
            linksSection
            licenseSection
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var appIconSection: some View {
        Image(nsImage: NSApp.applicationIconImage)
            .resizable()
            .frame(width: AboutViewConstants.appIconSize, height: AboutViewConstants.appIconSize)
    }

    private var appInfoSection: some View {
        Group {
            Text("Adobe Downloader \(appVersion)")
                .font(.system(size: AboutViewConstants.titleFontSize))
                .bold()

            Text("By X1a0He. ❤️ Love from China. 🇨🇳")
                .font(.system(size: AboutViewConstants.subtitleFontSize))
                .foregroundColor(.secondary)
        }
    }

    private var linksSection: some View {
        ForEach(AboutViewConstants.links, id: \.url) { link in
            ExternalLinkView(title: link.title, url: link.url)
        }
    }

    private var licenseSection: some View {
        Text("GNU通用公共许可证GPL v3.")
            .font(.system(size: AboutViewConstants.licenseFontSize))
            .foregroundColor(.secondary)
    }
}

struct PulsingCircle: View {
    let color: Color
    @State private var scale: CGFloat = 1.0

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
            .scaleEffect(scale)
            .animation(
                Animation.easeInOut(duration: 1.0)
                    .repeatForever(autoreverses: true),
                value: scale
            )
            .onAppear {
                scale = 1.5
            }
    }
}

final class GeneralSettingsViewModel: ObservableObject {
    @Published var setupVersion: String = ""
    @Published var isDownloadingSetup = false
    @Published var setupDownloadProgress = 0.0
    @Published var setupDownloadStatus = ""
    @Published var showAlert = false
    @Published var alertMessage = ""
    @Published var isSuccess = false
    @Published var showDownloadAlert = false
    @Published var showLanguagePicker = false
    @Published var showDownloadConfirmAlert = false
    @Published var showReprocessConfirmAlert = false
    @Published var showDownloadOnlyConfirmAlert = false
    @Published var isProcessing = false
    @Published var helperConnectionStatus: HelperConnectionStatus = .disconnected
    @Published var downloadAppleSilicon: Bool {
        didSet {
            StorageData.shared.downloadAppleSilicon = downloadAppleSilicon
        }
    }

    var defaultLanguage: String {
        get { StorageData.shared.defaultLanguage }
        set { StorageData.shared.defaultLanguage = newValue }
    }

    var defaultDirectory: String {
        get { StorageData.shared.defaultDirectory }
        set { StorageData.shared.defaultDirectory = newValue }
    }

    var useDefaultLanguage: Bool {
        get { StorageData.shared.useDefaultLanguage }
        set { StorageData.shared.useDefaultLanguage = newValue }
    }

    var useDefaultDirectory: Bool {
        get { StorageData.shared.useDefaultDirectory }
        set { StorageData.shared.useDefaultDirectory = newValue }
    }

    var confirmRedownload: Bool {
        get { StorageData.shared.confirmRedownload }
        set {
            StorageData.shared.confirmRedownload = newValue
            objectWillChange.send()
        }
    }

    @Published var automaticallyChecksForUpdates: Bool
    @Published var automaticallyDownloadsUpdates: Bool

    @Published var isCancelled = false

    private var cancellables = Set<AnyCancellable>()
    let updater: SPUUpdater

    enum HelperConnectionStatus {
        case connected
        case connecting
        case disconnected
        case checking
    }

    init(updater: SPUUpdater) {
        self.updater = updater
        self.automaticallyChecksForUpdates = updater.automaticallyChecksForUpdates
        self.automaticallyDownloadsUpdates = updater.automaticallyDownloadsUpdates
        self.downloadAppleSilicon = StorageData.shared.downloadAppleSilicon

        self.helperConnectionStatus = .connecting

        PrivilegedHelperManager.shared.$connectionState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                switch state {
                case .connected:
                    self?.helperConnectionStatus = .connected
                case .disconnected:
                    self?.helperConnectionStatus = .disconnected
                case .connecting:
                    self?.helperConnectionStatus = .connecting
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .storageDidChange)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    deinit {
        cancellables.removeAll()
    }

    func updateAutomaticallyChecksForUpdates(_ newValue: Bool) {
        automaticallyChecksForUpdates = newValue
        updater.automaticallyChecksForUpdates = newValue
    }

    func updateAutomaticallyDownloadsUpdates(_ newValue: Bool) {
        automaticallyDownloadsUpdates = newValue
        updater.automaticallyDownloadsUpdates = newValue
    }

    var isAutomaticallyDownloadsUpdatesDisabled: Bool {
        !automaticallyChecksForUpdates
    }

    func cancelDownload() {
        isCancelled = true
    }
}

struct GeneralSettingsView: View {
    @StateObject private var viewModel: GeneralSettingsViewModel
    @State private var showHelperAlert = false
    @State private var helperAlertMessage = ""
    @State private var helperAlertSuccess = false
    @EnvironmentObject private var networkManager: NetworkManager

    init(updater: SPUUpdater) {
        _viewModel = StateObject(wrappedValue: GeneralSettingsViewModel(updater: updater))
    }

    var body: some View {
        GeneralSettingsContent(
            viewModel: viewModel,
            showHelperAlert: $showHelperAlert,
            helperAlertMessage: $helperAlertMessage,
            helperAlertSuccess: $helperAlertSuccess
        )
    }
}

private struct GeneralSettingsContent: View {
    @ObservedObject var viewModel: GeneralSettingsViewModel
    @Binding var showHelperAlert: Bool
    @Binding var helperAlertMessage: String
    @Binding var helperAlertSuccess: Bool
    
    var body: some View {
        Form {
            DownloadSettingsView(viewModel: viewModel)
                .padding(.bottom, 8)
            HelperSettingsView(viewModel: viewModel,
                            showHelperAlert: $showHelperAlert,
                            helperAlertMessage: $helperAlertMessage,
                            helperAlertSuccess: $helperAlertSuccess)
                .padding(.bottom, 8)
            CCSettingsView(viewModel: viewModel)
                .padding(.bottom, 8)
            UpdateSettingsView(viewModel: viewModel)
                .padding(.bottom, 8)
            CleanConfigView()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .modifier(GeneralSettingsAlerts(
            viewModel: viewModel,
            showHelperAlert: $showHelperAlert,
            helperAlertMessage: $helperAlertMessage,
            helperAlertSuccess: $helperAlertSuccess
        ))
        .task {
            viewModel.setupVersion = ModifySetup.checkComponentVersion()
        }
        .onReceive(NotificationCenter.default.publisher(for: .storageDidChange)) { _ in
            viewModel.objectWillChange.send()
        }
    }
}

private struct GeneralSettingsAlerts: ViewModifier {
    @ObservedObject var viewModel: GeneralSettingsViewModel
    @Binding var showHelperAlert: Bool
    @Binding var helperAlertMessage: String
    @Binding var helperAlertSuccess: Bool
    @EnvironmentObject private var networkManager: NetworkManager
    
    func body(content: Content) -> some View {
        content
            .alert(helperAlertSuccess ? "操作成功" : "操作失败", isPresented: $showHelperAlert) {
                Button("确定") { }
            } message: {
                Text(helperAlertMessage)
            }
            .alert("需要下载 Setup 组件", isPresented: $viewModel.showDownloadAlert) {
                Button("取消", role: .cancel) { }
                Button("下载") {
                    Task {
                        startDownloadSetup(shouldProcess: false)
                    }
                }
            } message: {
                Text("检测到系统中不存在 Setup 组件，需要先下载组件才能继续操作。")
            }
            .alert("确认下载并处理", isPresented: $viewModel.showDownloadConfirmAlert) {
                Button("取消", role: .cancel) { }
                Button("确定") {
                    Task {
                        startDownloadSetup(shouldProcess: true)
                    }
                }
            } message: {
                Text("确定要下载并处理 X1a0He CC 吗？这将完成下载并自动对 Setup 组件进行处理")
            }
            .alert("确认处理", isPresented: $viewModel.showReprocessConfirmAlert) {
                Button("取消", role: .cancel) { }
                Button("确定") {
                    Task {
                        viewModel.isProcessing = true
                        ModifySetup.backupAndModifySetupFile { success, message in
                            viewModel.setupVersion = ModifySetup.checkComponentVersion()
                            viewModel.isSuccess = success
                            viewModel.alertMessage = success ? "Setup 组件处理成功" : "处理失败: \(message)"
                            viewModel.showAlert = true
                            viewModel.isProcessing = false
                        }
                    }
                }
            } message: {
                Text("确定要重新处理 Setup 组件吗？这将对 Setup 组件进行修改以启用安装功能。")
            }
            .alert(viewModel.isSuccess ? "操作成功" : "操作失败", isPresented: $viewModel.showAlert) {
                Button("确定") { }
            } message: {
                Text(viewModel.alertMessage)
            }
            .alert("确认下载", isPresented: $viewModel.showDownloadOnlyConfirmAlert) {
                Button("取消", role: .cancel) { }
                Button("确定") {
                    Task {
                        startDownloadSetup(shouldProcess: false)
                    }
                }
            } message: {
                Text("确定要下载 X1a0He CC 吗？下载完成后需要手动处理。")
            }
    }
    
    private func startDownloadSetup(shouldProcess: Bool) {
        viewModel.isDownloadingSetup = true
        viewModel.isCancelled = false
        
        Task {
            do {
                try await globalNewDownloadUtils.downloadX1a0HeCCPackages(
                    progressHandler: { progress, status in
                        viewModel.setupDownloadProgress = progress
                        viewModel.setupDownloadStatus = status
                    },
                    cancellationHandler: { viewModel.isCancelled },
                    shouldProcess: shouldProcess
                )
                viewModel.setupVersion = ModifySetup.checkComponentVersion()
                viewModel.isSuccess = true
                viewModel.alertMessage = String(localized: shouldProcess ? 
                                              "X1a0He CC 下载并处理成功" : 
                                              "X1a0He CC 下载成功")
            } catch NetworkError.cancelled {
                viewModel.isSuccess = false
                viewModel.alertMessage = String(localized: "下载已取消")
            } catch {
                viewModel.isSuccess = false
                viewModel.alertMessage = error.localizedDescription
            }
            
            viewModel.showAlert = true
            viewModel.isDownloadingSetup = false
        }
    }
}

struct BeautifulGroupBox<Label: View, Content: View>: View {
    let label: Label
    let content: Content
    
    init(label: @escaping () -> Label, @ViewBuilder content: () -> Content) {
        self.label = label()
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            label
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary.opacity(0.85))
            
            VStack(alignment: .leading, spacing: 0) {
                content
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(NSColor.controlBackgroundColor).opacity(0.7))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.15), lineWidth: 1)
                    )
            )
        }
    }
}

struct DownloadSettingsView: View {
    @ObservedObject var viewModel: GeneralSettingsViewModel

    var body: some View {
        BeautifulGroupBox(label: { 
            Text("下载设置")
        }) {
            VStack(alignment: .leading, spacing: 8) {
                LanguageSettingRow(viewModel: viewModel)
                    .fixedSize(horizontal: false, vertical: true)
                
                Divider()
                
                DirectorySettingRow(viewModel: viewModel)
                    .fixedSize(horizontal: false, vertical: true)
                
                Divider()
                
                RedownloadConfirmRow(viewModel: viewModel)
                    .fixedSize(horizontal: false, vertical: true)
                
                HStack {
                    Spacer()
                    Rectangle()
                        .fill(Color.secondary.opacity(0.15))
                        .frame(height: 1)
                    Spacer()
                }
                
                ArchitectureSettingRow(viewModel: viewModel)
            }
        }
    }
}

struct HelperSettingsView: View {
    @ObservedObject var viewModel: GeneralSettingsViewModel
    @Binding var showHelperAlert: Bool
    @Binding var helperAlertMessage: String
    @Binding var helperAlertSuccess: Bool

    var body: some View {
        BeautifulGroupBox(label: { 
            Text("Helper 设置")
        }) {
            VStack(alignment: .leading, spacing: 8) {
                HelperStatusRow(viewModel: viewModel, showHelperAlert: $showHelperAlert,
                              helperAlertMessage: $helperAlertMessage,
                              helperAlertSuccess: $helperAlertSuccess)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct CCSettingsView: View {
    @ObservedObject var viewModel: GeneralSettingsViewModel

    var body: some View {
        BeautifulGroupBox(label: { 
            Text("X1a0He CC设置")
        }) {
            VStack(alignment: .leading, spacing: 16) {
                SetupComponentRow(viewModel: viewModel)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct UpdateSettingsView: View {
    @ObservedObject var viewModel: GeneralSettingsViewModel
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }
    private var buildVersion: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }

    var body: some View {
        BeautifulGroupBox(label: { 
            Text("更新设置")
        }) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("当前版本: ")
                        .font(.system(size: 14, weight: .medium))
                    
                    HStack(spacing: 4) {
                        Image(systemName: "number.circle.fill")
                            .foregroundColor(.blue)
                            .font(.system(size: 12))
                            .frame(width: 16, height: 16)
                        Text(appVersion)
                            .foregroundColor(.secondary)
                            .font(.system(size: 13))
                        Text("(\(buildVersion))")
                            .foregroundColor(.secondary)
                            .font(.system(size: 13))
                    }
                    .padding(.vertical, 3)
                    .padding(.horizontal, 8)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(5)
                }
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, 2)

                Divider()

                AutoUpdateRow(viewModel: viewModel)
                    .fixedSize(horizontal: false, vertical: true)
                
                Divider()
                
                AutoDownloadRow(viewModel: viewModel)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct CleanConfigView: View {
    @State private var showConfirmation = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var chipInfo: String = ""
    
    private func getChipInfo() -> String {
        var size = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
        var machine = [CChar](repeating: 0, count: size)
        sysctlbyname("machdep.cpu.brand_string", &machine, &size, nil, 0)
        let chipName = String(cString: machine)
        
        if chipName.contains("Apple") {
            return chipName
        } else {
            return chipName.components(separatedBy: "@")[0].trimmingCharacters(in: .whitespaces)
        }
    }

    var body: some View {
        HStack(spacing: 16) {
            BeautifulGroupBox(label: { 
                Text("重置程序")
            }) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Button("重置程序") {
                            showConfirmation = true
                        }
                        .buttonStyle(BeautifulButtonStyle(baseColor: .red.opacity(0.8)))
                        .foregroundColor(.white)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
            
            BeautifulGroupBox(label: { 
                Text("系统信息")
            }) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "desktopcomputer")
                            .foregroundColor(.blue)
                            .imageScale(.medium)
                            .frame(width: 22, height: 22)
                            .background(Circle().fill(Color.blue.opacity(0.1)).frame(width: 28, height: 28))
                        
                        VStack(alignment: .leading, spacing: 1) {
                            Text("macOS \(ProcessInfo.processInfo.operatingSystemVersionString)")
                                .fontWeight(.medium)
                            
                            Text("\(chipInfo.isEmpty ? "加载中..." : chipInfo)")
                                .foregroundColor(.secondary)
                                .font(.system(size: 12))
                        }
                        Spacer()
                    }
                }
            }
        }
        .alert("确认重置程序", isPresented: $showConfirmation) {
            Button("取消", role: .cancel) { }
            Button("确定", role: .destructive) {
                cleanConfig()
            }
        } message: {
            Text("这将清空所有配置并结束应用程序，确定要继续吗？")
        }
        .alert("操作结果", isPresented: $showAlert) {
            Button("确定") { }
        } message: {
            Text(alertMessage)
        }
        .onAppear {
            chipInfo = getChipInfo()
        }
    }

    private func cleanConfig() {
        do {
            let downloadsURL = try FileManager.default.url(for: .downloadsDirectory,
                                                         in: .userDomainMask,
                                                         appropriateFor: nil,
                                                         create: false)
            let scriptURL = downloadsURL.appendingPathComponent("clean-config.sh")

            guard let scriptPath = Bundle.main.path(forResource: "clean-config", ofType: "sh"),
                  let scriptContent = try? String(contentsOfFile: scriptPath, encoding: .utf8) else {
                throw NSError(domain: "ScriptError", code: 1, userInfo: [NSLocalizedDescriptionKey: "无法读取脚本文件"])
            }

            try scriptContent.write(to: scriptURL, atomically: true, encoding: .utf8)

            try FileManager.default.setAttributes([.posixPermissions: 0o755],
                                                ofItemAtPath: scriptURL.path)

            if PrivilegedHelperManager.getHelperStatus {
                PrivilegedHelperManager.shared.executeCommand("open -a Terminal \(scriptURL.path)") { output in
                    if output.starts(with: "Error") {
                        alertMessage = "清空配置失败: \(output)"
                        showAlert = true
                    } else {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            exit(0)
                        }
                    }
                }
            } else {
                let terminalURL = URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app")
                NSWorkspace.shared.open([scriptURL],
                                        withApplicationAt: terminalURL,
                                           configuration: NSWorkspace.OpenConfiguration()) { _, error in
                    if let error = error {
                        alertMessage = "打开终端失败: \(error.localizedDescription)"
                        showAlert = true
                        return
                    }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        exit(0)
                    }
                }
            }

        } catch {
            alertMessage = "清空配置失败: \(error.localizedDescription)"
            showAlert = true
        }
    }
}

private class PreviewUpdater: SPUUpdater {
    init() {
        let hostBundle = Bundle.main
        let applicationBundle = Bundle.main
        let userDriver = SPUStandardUserDriver(hostBundle: hostBundle, delegate: nil)

        super.init(
            hostBundle: hostBundle,
            applicationBundle: applicationBundle,
            userDriver: userDriver,
            delegate: nil
        )
    }

    override var automaticallyChecksForUpdates: Bool {
        get { true }
        set { }
    }

    override var automaticallyDownloadsUpdates: Bool {
        get { true }
        set { }
    }
}

struct LanguageSettingRow: View {
    @ObservedObject var viewModel: GeneralSettingsViewModel

    var body: some View {
        HStack(spacing: 10) {
            Toggle("使用默认语言", isOn: Binding(
                get: { viewModel.useDefaultLanguage },
                set: { viewModel.useDefaultLanguage = $0 }
            ))
            .toggleStyle(SwitchToggleStyle(tint: Color.green))
                .padding(.leading, 5)
                .controlSize(.small)
                .labelsHidden()
                
            Text("使用默认语言")
                .font(.system(size: 14))
                
            Spacer()
            
            if viewModel.useDefaultLanguage {
                HStack(spacing: 4) {
                    Image(systemName: "globe")
                        .foregroundColor(.secondary)
                        .font(.system(size: 12))
                    Text(getLanguageName(code: viewModel.defaultLanguage))
                        .foregroundColor(.secondary)
                        .font(.system(size: 13))
                }
                .padding(.vertical, 3)
                .padding(.horizontal, 8)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(5)
                
                Button(action: {
                    viewModel.showLanguagePicker = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "pencil")
                            .font(.system(size: 10))
                        Text("选择")
                            .font(.system(size: 13))
                    }
                    .frame(minWidth: 60)
                }
                .buttonStyle(BeautifulButtonStyle(baseColor: Color.blue.opacity(0.8)))
                .foregroundColor(.white)
                .padding(.trailing, 5)
                .disabled(!viewModel.useDefaultLanguage)
            }
        }
        .sheet(isPresented: $viewModel.showLanguagePicker) {
            LanguagePickerView(languages: AppStatics.supportedLanguages) { language in
                viewModel.defaultLanguage = language
                viewModel.showLanguagePicker = false
            }
        }
    }

    private func getLanguageName(code: String) -> String {
        AppStatics.supportedLanguages.first { $0.code == code }?.name ?? code
    }
}

struct DirectorySettingRow: View {
    @ObservedObject var viewModel: GeneralSettingsViewModel

    var body: some View {
        HStack(spacing: 10) {
            Toggle("使用默认目录", isOn: $viewModel.useDefaultDirectory)
                .toggleStyle(SwitchToggleStyle(tint: Color.green))
                .padding(.leading, 5)
                .controlSize(.small)
                .labelsHidden()
                
            Text("使用默认目录")
                .font(.system(size: 14))
                
            Spacer()
            
            if viewModel.useDefaultDirectory {
                HStack(spacing: 4) {
                    Image(systemName: "folder")
                        .foregroundColor(.secondary)
                        .font(.system(size: 12))
                        .frame(width: 16)
                    Text(formatPath(viewModel.defaultDirectory))
                        .foregroundColor(.secondary)
                        .font(.system(size: 13))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .padding(.vertical, 3)
                .padding(.horizontal, 8)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(5)
                
                Button(action: {
                    selectDirectory()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: 10))
                        Text("选择")
                            .font(.system(size: 13))
                    }
                    .frame(minWidth: 60)
                }
                .buttonStyle(BeautifulButtonStyle(baseColor: Color.blue.opacity(0.8)))
                .foregroundColor(.white)
                .padding(.trailing, 5)
                .disabled(!viewModel.useDefaultDirectory)
            }
        }
    }

    private func formatPath(_ path: String) -> String {
        if path.isEmpty { return String(localized: "未设置") }
        return URL(fileURLWithPath: path).lastPathComponent
    }

    private func selectDirectory() {
        let panel = NSOpenPanel()
        panel.title = "选择默认下载目录"
        panel.canCreateDirectories = true
        panel.canChooseDirectories = true
        panel.canChooseFiles = false

        if panel.runModal() == .OK {
            viewModel.defaultDirectory = panel.url?.path ?? ""
            viewModel.useDefaultDirectory = true
        }
    }
}

struct RedownloadConfirmRow: View {
    @ObservedObject var viewModel: GeneralSettingsViewModel

    var body: some View {
        HStack(spacing: 10) {
            Toggle("重新下载时需要确认", isOn: $viewModel.confirmRedownload)
                .toggleStyle(SwitchToggleStyle(tint: Color.green))
                .padding(.leading, 5)
                .controlSize(.small)
                .labelsHidden()
                
            Text("重新下载时需要确认")
                .font(.system(size: 14))
            
            Spacer()
            
            if viewModel.confirmRedownload {
                HStack(spacing: 5) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                        .font(.system(size: 12))
                    Text("已启用确认")
                        .foregroundColor(.secondary)
                        .font(.system(size: 13))
                }
                .padding(.vertical, 3)
                .padding(.horizontal, 8)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(5)
                .padding(.trailing, 5)
            }
        }
    }
}

struct ArchitectureSettingRow: View {
    @ObservedObject var viewModel: GeneralSettingsViewModel
    @ObservedObject private var networkManager = globalNetworkManager

    var body: some View {
        HStack(spacing: 10) {
            Toggle("下载 Apple Silicon 架构", isOn: $viewModel.downloadAppleSilicon)
                .toggleStyle(SwitchToggleStyle(tint: Color.green))
                .padding(.leading, 5)
                .controlSize(.small)
                .disabled(networkManager.loadingState == .loading)
                .labelsHidden()
                
            Text("下载 Apple Silicon 架构")
                .font(.system(size: 14))
            
            Spacer()
            
            HStack(spacing: 5) {
                Image(systemName: "cpu")
                    .foregroundColor(.secondary)
                    .font(.system(size: 12))
                Text("当前架构: \(AppStatics.cpuArchitecture)")
                    .foregroundColor(.secondary)
                    .font(.system(size: 13))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .padding(.vertical, 3)
            .padding(.horizontal, 8)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(5)
            .padding(.trailing, 5)
            
            if networkManager.loadingState == .loading {
                ProgressView()
                    .scaleEffect(0.7)
                    .padding(.trailing, 5)
            }
        }
        .onChange(of: viewModel.downloadAppleSilicon) { newValue in
            Task {
                await networkManager.fetchProducts()
            }
        }
    }
}

struct HelperStatusRow: View {
    @ObservedObject var viewModel: GeneralSettingsViewModel
    @Binding var showHelperAlert: Bool
    @Binding var helperAlertMessage: String
    @Binding var helperAlertSuccess: Bool
    @State private var isReinstallingHelper = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text("安装状态: ")
                    .font(.system(size: 14, weight: .medium))
                    
                if PrivilegedHelperManager.getHelperStatus {
                    HStack(spacing: 5) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 14))
                        Text("已安装 (build \(UserDefaults.standard.string(forKey: "InstalledHelperBuild") ?? "0"))")
                            .font(.system(size: 14))
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(6)
                } else {
                    HStack(spacing: 5) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                            .font(.system(size: 14))
                        Text("未安装")
                            .foregroundColor(.red)
                            .font(.system(size: 14))
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(6)
                }
                
                Spacer()

                if isReinstallingHelper {
                    ProgressView()
                        .scaleEffect(0.8)
                        .padding(.trailing, 5)
                }

                Button(action: {
                    isReinstallingHelper = true
                    PrivilegedHelperManager.shared.removeInstallHelper()
                    PrivilegedHelperManager.shared.reinstallHelper { success, message in
                        helperAlertSuccess = success
                        helperAlertMessage = message
                        showHelperAlert = true
                        isReinstallingHelper = false
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 12))
                        Text("重新安装")
                            .font(.system(size: 13))
                    }
                    .frame(minWidth: 90)
                }
                .buttonStyle(BeautifulButtonStyle(baseColor: Color.blue.opacity(0.8)))
                .foregroundColor(.white)
                .disabled(isReinstallingHelper)
                .help("完全卸载并重新安装 Helper")
            }

            if !PrivilegedHelperManager.getHelperStatus {
                Text("Helper 未安装将导致无法执行需要管理员权限的操作")
                    .font(.caption)
                    .foregroundColor(.red)
            }

            Divider()

            HStack(spacing: 10) {
                Text("连接状态: ")
                    .font(.system(size: 14, weight: .medium))
                
                HStack(spacing: 5) {
                    PulsingCircle(color: helperStatusColor)
                        .frame(width: 12, height: 12)
                    Text(helperStatusText)
                        .font(.system(size: 14))
                        .foregroundColor(helperStatusColor)
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(helperStatusBackgroundColor)
                .cornerRadius(6)

                Spacer()

                Button(action: {
                    if PrivilegedHelperManager.getHelperStatus &&
                       viewModel.helperConnectionStatus != .connected {
                        PrivilegedHelperManager.shared.reconnectHelper { success, message in
                            helperAlertSuccess = success
                            helperAlertMessage = message
                            showHelperAlert = true
                        }
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "network")
                            .font(.system(size: 12))
                        Text("重新连接")
                            .font(.system(size: 13))
                    }
                    .frame(minWidth: 90)
                }
                .buttonStyle(BeautifulButtonStyle(baseColor: shouldDisableReconnectButton ? Color.gray.opacity(0.6) : Color.blue.opacity(0.8)))
                .foregroundColor(shouldDisableReconnectButton ? Color.white.opacity(0.8) : .white)
                .disabled(shouldDisableReconnectButton)
                .help("尝试重新连接到已安装的 Helper")
            }
        }
    }

    private var helperStatusColor: Color {
        switch viewModel.helperConnectionStatus {
        case .connected: return .green
        case .connecting: return .orange
        case .disconnected: return .red
        case .checking: return .orange
        }
    }
    
    private var shouldDisableReconnectButton: Bool {
        return !PrivilegedHelperManager.getHelperStatus || 
               viewModel.helperConnectionStatus == .connected || 
               isReinstallingHelper
    }

    private var helperStatusBackgroundColor: Color {
        switch viewModel.helperConnectionStatus {
        case .connected: return Color.green.opacity(0.1)
        case .connecting: return Color.orange.opacity(0.1)
        case .disconnected: return Color.red.opacity(0.1)
        case .checking: return Color.orange.opacity(0.1)
        }
    }

    private var helperStatusText: String {
        switch viewModel.helperConnectionStatus {
        case .connected: return String(localized: "运行正常")
        case .connecting: return String(localized: "正在连接")
        case .disconnected: return String(localized: "连接断开")
        case .checking: return String(localized: "检查中")
        }
    }
}

struct SetupComponentRow: View {
    @ObservedObject var viewModel: GeneralSettingsViewModel
    @State private var chipInfo: String = ""
    
    private func getChipInfo() -> String {
        var size = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
        var machine = [CChar](repeating: 0, count: size)
        sysctlbyname("machdep.cpu.brand_string", &machine, &size, nil, 0)
        let chipName = String(cString: machine)
        
        if chipName.contains("Apple") {
            return chipName
        } else {
            return chipName.components(separatedBy: "@")[0].trimmingCharacters(in: .whitespaces)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("备份状态: ")
                    .font(.system(size: 14, weight: .medium))
                    
                #if DEBUG
                HStack(spacing: 4) {
                    Image(systemName: "ladybug.fill")
                        .foregroundColor(.yellow)
                        .font(.system(size: 12))
                        .frame(width: 16, height: 16)
                    Text("Debug 模式")
                        .foregroundColor(.secondary)
                        .font(.system(size: 13))
                }
                .padding(.vertical, 3)
                .padding(.horizontal, 8)
                .background(Color.yellow.opacity(0.1))
                .cornerRadius(5)
                #else
                if ModifySetup.isSetupBackup() {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 12))
                            .frame(width: 16, height: 16)
                        Text("已备份")
                            .foregroundColor(.secondary)
                            .font(.system(size: 13))
                    }
                    .padding(.vertical, 3)
                    .padding(.horizontal, 8)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(5)
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                            .font(.system(size: 12))
                            .frame(width: 16, height: 16)
                        Text("未备份")
                            .foregroundColor(.secondary)
                            .font(.system(size: 13))
                    }
                    .padding(.vertical, 3)
                    .padding(.horizontal, 8)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(5)
                    
                    Text("(可能导致处理失败)")
                        .foregroundColor(.red.opacity(0.8))
                        .font(.system(size: 12))
                        .padding(.leading, 2)
                }
                #endif
                
                Spacer()
            }
            Divider()
            
            HStack {
                Text("处理状态: ")
                    .font(.system(size: 14, weight: .medium))
                    
                #if DEBUG
                HStack(spacing: 4) {
                    Image(systemName: "ladybug.fill")
                        .foregroundColor(.yellow)
                        .font(.system(size: 12))
                        .frame(width: 16, height: 16)
                    Text("Debug 模式")
                        .foregroundColor(.secondary)
                        .font(.system(size: 13))
                }
                .padding(.vertical, 3)
                .padding(.horizontal, 8)
                .background(Color.yellow.opacity(0.1))
                .cornerRadius(5)
                #else
                if ModifySetup.isSetupModified() {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 12))
                            .frame(width: 16, height: 16)
                        Text("已处理")
                            .foregroundColor(.secondary)
                            .font(.system(size: 13))
                    }
                    .padding(.vertical, 3)
                    .padding(.horizontal, 8)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(5)
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                            .font(.system(size: 12))
                            .frame(width: 16, height: 16)
                        Text("未处理")
                            .foregroundColor(.secondary)
                            .font(.system(size: 13))
                    }
                    .padding(.vertical, 3)
                    .padding(.horizontal, 8)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(5)
                    
                    Text("(无法使用安装功能)")
                        .foregroundColor(.red.opacity(0.8))
                        .font(.system(size: 12))
                        .padding(.leading, 2)
                }
                #endif
                
                Spacer()

                Button(action: {
                    if !ModifySetup.isSetupExists() {
                        viewModel.showDownloadAlert = true
                    } else {
                        viewModel.showReprocessConfirmAlert = true
                    }
                }) {
                    Text("重新处理")
                }
                .buttonStyle(BeautifulButtonStyle(baseColor: Color.blue.opacity(0.8)))
                .foregroundColor(.white)
            }
            Divider()
            
            HStack {
                Text("版本信息: ")
                    .font(.system(size: 14, weight: .medium))
                    
                HStack(spacing: 5) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.blue)
                        .font(.system(size: 12))
                        .frame(width: 16, height: 16)
                    Text("\(viewModel.setupVersion)")
                        .foregroundColor(.secondary)
                        .font(.system(size: 14))
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(5)

                Spacer()

                if viewModel.isDownloadingSetup {
                    ProgressView(value: viewModel.setupDownloadProgress) {
                        Text(viewModel.setupDownloadStatus)
                            .font(.caption)
                    }
                    .frame(width: 150)
                    Button("取消") {
                        viewModel.cancelDownload()
                    }
                    .buttonStyle(BeautifulButtonStyle(baseColor: Color.red.opacity(0.8)))
                    .foregroundColor(.white)
                } else {
                    Menu {
                        Button(action: {
                            viewModel.showDownloadConfirmAlert = true
                        }) {
                            Label("下载并处理", systemImage: "arrow.down.circle.fill")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        Button(action: {
                            viewModel.showDownloadOnlyConfirmAlert = true
                        }) {
                            Label("仅下载", systemImage: "arrow.down")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    } label: {
                        Text("X1a0He CC 选项")
                            .frame(width: 100)
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                    .help("选择下载 X1a0He CC 的方式")
                }
            }
        }
        .onAppear {
            chipInfo = getChipInfo()
        }
    }
}

struct AutoUpdateRow: View {
    @ObservedObject var viewModel: GeneralSettingsViewModel

    var body: some View {
        HStack {
            Toggle("", isOn: Binding(
                get: { viewModel.automaticallyChecksForUpdates },
                set: { viewModel.updateAutomaticallyChecksForUpdates($0) }
            ))
            .toggleStyle(SwitchToggleStyle(tint: Color.green))
            .controlSize(.small)
            .labelsHidden()
            
            Text("自动检查更新版本")
                .font(.system(size: 14))
            
            Spacer()
            
            if viewModel.automaticallyChecksForUpdates {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 12))
                        .frame(width: 16, height: 16)
                    Text("已启用")
                        .foregroundColor(.secondary)
                        .font(.system(size: 13))
                }
                .padding(.vertical, 3)
                .padding(.horizontal, 8)
                .background(Color.green.opacity(0.1))
                .cornerRadius(5)
            }
            
            CheckForUpdatesView(updater: viewModel.updater)
                .buttonStyle(BeautifulButtonStyle(baseColor: Color.blue.opacity(0.8)))
                .foregroundColor(.white)
        }
    }
}

struct AutoDownloadRow: View {
    @ObservedObject var viewModel: GeneralSettingsViewModel

    var body: some View {
        HStack {
            Toggle("", isOn: Binding(
                get: { viewModel.automaticallyDownloadsUpdates },
                set: { viewModel.updateAutomaticallyDownloadsUpdates($0) }
            ))
            .toggleStyle(SwitchToggleStyle(tint: Color.green))
            .controlSize(.small)
            .labelsHidden()
            .disabled(viewModel.isAutomaticallyDownloadsUpdatesDisabled)
            
            Text("自动下载最新版本")
                .font(.system(size: 14))
                .foregroundColor(viewModel.isAutomaticallyDownloadsUpdatesDisabled ? .gray : .primary)
            
            Spacer()
            
            if viewModel.automaticallyDownloadsUpdates && !viewModel.isAutomaticallyDownloadsUpdatesDisabled {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 12))
                        .frame(width: 16, height: 16)
                    Text("已启用")
                        .foregroundColor(.secondary)
                        .font(.system(size: 13))
                }
                .padding(.vertical, 3)
                .padding(.horizontal, 8)
                .background(Color.green.opacity(0.1))
                .cornerRadius(5)
            } else if viewModel.isAutomaticallyDownloadsUpdatesDisabled {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.gray)
                        .font(.system(size: 12))
                        .frame(width: 16, height: 16)
                    Text("需先启用自动检查")
                        .foregroundColor(.secondary)
                        .font(.system(size: 13))
                }
                .padding(.vertical, 3)
                .padding(.horizontal, 8)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(5)
            }
        }
    }
}

struct QAView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Group {
                    QAItem(
                        question: String(localized: "为什么需要安装 Helper？"),
                        answer: String(localized: "Helper 是一个具有管理员权限的辅助工具，用于执行需要管理员权限的操作，如修改系统文件等。没有 Helper 将无法正常使用软件的某些功能。")
                    )

                    QAItem(
                        question: String(localized: "为什么需要下载 Setup 组件？"),
                        answer: String(localized: "Setup 组件是 Adobe 官方的安装程序组件，我们需要对其进行修改以实现绕过验证的功能。如果没有下载并处理 Setup 组件，将无法使用安装功能。")
                    )

                    QAItem(
                        question: String(localized: "为什么有时候下载会失败？"),
                        answer: String(localized: "下载失败可能有多种原因：\n1. 网络连接不稳定\n2. Adobe 服务器响应超时\n3. 本地磁盘空间不足\n建议您检查网络连接并重试，如果问题持续存在，可以尝试使用代理或 VPN。")
                    )

                    QAItem(
                        question: String(localized: "如何修复安装失败的问题？"),
                        answer: String(localized: "如果安装失败，您可以尝试以下步骤：\n1. 确保已正确安装并连接 Helper\n2. 确保已下载并处理 Setup 组件\n3. 检查磁盘剩余空间是否充足\n4. 尝试重新下载并安装\n如果问题仍然存在，可以尝试重新安装 Helper 和重新处理 Setup 组件。")
                    )
                }
            }
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct QAItem: View {
    let question: String
    let answer: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(question)
                .font(.headline)
                .foregroundColor(.primary)

            Text(answer)
                .font(.body)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()
        }
    }
}

struct CleanupLog: Identifiable {
    let id = UUID()
    let timestamp: Date
    let command: String
    let status: LogStatus
    let message: String

    enum LogStatus {
        case running
        case success
        case error
        case cancelled
    }

    static func getCleanupDescription(for command: String) -> String {
        if command.contains("Library/Logs") || command.contains("DiagnosticReports") {
            if command.contains("Adobe Creative Cloud") {
                return String(localized: "正在清理 Creative Cloud 日志文件...")
            } else if command.contains("CrashReporter") {
                return String(localized: "正在清理崩溃报告日志...")
            } else {
                return String(localized: "正在清理应用程序日志文件...")
            }
        } else if command.contains("Library/Caches") {
            return String(localized: "正在清理缓存文件...")
        } else if command.contains("Library/Preferences") {
            return String(localized: "正在清理偏好设置文件...")
        } else if command.contains("Applications") {
            if command.contains("Creative Cloud") {
                return String(localized: "正在清理 Creative Cloud 应用...")
            } else {
                return String(localized: "正在清理 Adobe 应用程序...")
            }
        } else if command.contains("LaunchAgents") || command.contains("LaunchDaemons") {
            return String(localized: "正在清理启动项服务...")
        } else if command.contains("security") {
            return String(localized: "正在清理钥匙串数据...")
        } else if command.contains("AdobeGenuineClient") || command.contains("AdobeGCClient") {
            return String(localized: "正在清理正版验证服务...")
        } else if command.contains("hosts") {
            return String(localized: "正在清理 hosts 文件...")
        } else if command.contains("kill") {
            return String(localized: "正在停止 Adobe 相关进程...")
        } else if command.contains("receipts") {
            return String(localized: "正在清理安装记录...")
        } else {
            return String(localized: "正在清理其他文件...")
        }
    }
}

struct CleanupView: View {
    @State private var showConfirmation = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var selectedOptions = Set<CleanupOption>()
    @State private var isProcessing = false
    @State private var cleanupLogs: [CleanupLog] = []
    @State private var currentCommandIndex = 0
    @State private var totalCommands = 0
    @State private var expandedOptions = Set<CleanupOption>()
    @State private var isCancelled = false
    @State private var isLogExpanded = false

    enum CleanupOption: String, CaseIterable, Identifiable {
        case adobeApps = "Adobe 应用程序"
        case adobeCreativeCloud = "Adobe Creative Cloud"
        case adobePreferences = "Adobe 偏好设置"
        case adobeCaches = "Adobe 缓存文件"
        case adobeLicenses = "Adobe 许可文件"
        case adobeLogs = "Adobe 日志文件"
        case adobeServices = "Adobe 服务"
        case adobeKeychain = "Adobe 钥匙串"
        case adobeGenuineService = "Adobe 正版验证服务"
        case adobeHosts = "Adobe Hosts"

        var id: String { self.rawValue }

        var localizedName: String {
            switch self {
            case .adobeApps:
                return String(localized: "Adobe 应用程序")
            case .adobeCreativeCloud:
                return String(localized: "Adobe Creative Cloud")
            case .adobePreferences:
                return String(localized: "Adobe 偏好设置")
            case .adobeCaches:
                return String(localized: "Adobe 缓存文件")
            case .adobeLicenses:
                return String(localized: "Adobe 许可文件")
            case .adobeLogs:
                return String(localized: "Adobe 日志文件")
            case .adobeServices:
                return String(localized: "Adobe 服务")
            case .adobeKeychain:
                return String(localized: "Adobe 钥匙串")
            case .adobeGenuineService:
                return String(localized: "Adobe 正版验证服务")
            case .adobeHosts:
                return String(localized: "Adobe Hosts")
            }
        }

        var commands: [String] {
            switch self {
            case .adobeApps:
                return [
                    "sudo find /Applications -name 'Adobe*' ! -name '*Adobe Downloader*' -print0 | xargs -0 sudo rm -rf",
                    "sudo find /Applications/Utilities -name 'Adobe*' ! -name '*Adobe Downloader*' -print0 | xargs -0 sudo rm -rf",
                    "sudo rm -rf /Applications/Adobe Creative Cloud",
                    "sudo rm -rf /Applications/Utilities/Adobe Creative Cloud",
                    "sudo rm -rf /Applications/Utilities/Adobe Creative Cloud Experience",
                    "sudo rm -rf /Applications/Utilities/Adobe Installers/Uninstall Adobe Creative Cloud",
                    "sudo rm -rf /Applications/Utilities/Adobe Sync",
                    "sudo rm -rf /Applications/Utilities/Adobe Genuine Service"
                ]
            case .adobeCreativeCloud:
                return [
                    "sudo rm -rf /Library/Application Support/Adobe/Adobe Desktop Common/ADBox",
                    "sudo rm -rf /Library/Application Support/Adobe/Adobe Desktop Common/ADS",
                    "sudo rm -rf /Library/Application Support/Adobe/Adobe Desktop Common/AppsPanel",
                    "sudo rm -rf /Library/Application Support/Adobe/Adobe Desktop Common/CEF",
                    "sudo rm -rf /Library/Application Support/Adobe/Adobe Desktop Common/Core",
                    "sudo rm -rf /Library/Application Support/Adobe/Adobe Desktop Common/CoreExt",
                    "sudo rm -rf /Library/Application Support/Adobe/Adobe Desktop Common/DEBox",
                    "sudo rm -rf /Library/Application Support/Adobe/Adobe Desktop Common/ElevationManager",
                    "sudo rm -rf /Library/Application Support/Adobe/Adobe Desktop Common/FilesPanel",
                    "sudo rm -rf /Library/Application Support/Adobe/Adobe Desktop Common/FontsPanel",
                    "sudo rm -rf /Library/Application Support/Adobe/Adobe Desktop Common/HEX",
                    "sudo rm -rf /Library/Application Support/Adobe/Adobe Desktop Common/LCC",
                    "sudo rm -rf /Library/Application Support/Adobe/Adobe Desktop Common/NHEX",
                    "sudo rm -rf /Library/Application Support/Adobe/Adobe Desktop Common/Notifications",
                    "sudo rm -rf /Library/Application Support/Adobe/Adobe Desktop Common/pim.db",
                    "sudo rm -rf /Library/Application Support/Adobe/Adobe Desktop Common/RemoteComponents",
                    "sudo rm -rf /Library/Application Support/Adobe/Adobe Desktop Common/TCC",
                    "sudo rm -rf /Library/Application Support/Adobe/ARMNext",
                    "sudo rm -rf /Library/Application Support/Adobe/ARMDC/Application",
                    "sudo rm -rf /Library/Application Support/Adobe/PII/com.adobe.pii.prefs",
                    "sudo rm -rf /Library/Application Support/Adobe/ACPLocal*",
                    "sudo rm -rf /Library/Application Support/regid.1986-12.com.adobe",
                    "sudo rm -rf /Library/Internet Plug-Ins/AdobeAAMDetect.plugin",
                    "sudo rm -rf /Library/Internet Plug-Ins/AdobePDF*",
                    "sudo rm -rf /Library/PDF Services/Save as Adobe PDF*",
                    "sudo rm -rf /Library/ScriptingAdditions/Adobe Unit Types.osax",
                    "sudo rm -rf /Library/Automator/Save as Adobe PDF.action",
                    "sudo rm -rf ~/.adobe",
                    "sudo rm -rf ~/Creative Cloud Files*",
                    "sudo find ~/Library/Application\\ Scripts -name '*com.adobe*' ! -name '*Adobe Downloader*' -print0 | xargs -0 sudo rm -rf || true",
                    "sudo find ~/Library/Group\\ Containers -name '*com.adobe*' ! -name '*Adobe Downloader*' -print0 | xargs -0 sudo rm -rf || true",
                    "sudo rm -rf ~/Library/Application\\ Scripts/Adobe-Hub-App || true",
                    "sudo rm -rf ~/Library/Group\\ Containers/Adobe-Hub-App || true",
                    "sudo rm -rf ~/Library/Application\\ Support/com.apple.sharedfilelist/com.apple.LSSharedFileList.ApplicationRecentDocuments/com.adobe* || true",
                    "sudo find ~/Library/Application\\ Support -name 'Acrobat*' ! -path '*/Adobe Downloader/*' -print0 | xargs -0 sudo rm -rf || true",
                    "sudo find ~/Library/Application\\ Support -name 'Adobe*' ! -name '*Adobe Downloader*' ! -path '*/Adobe Downloader/*' -print0 | xargs -0 sudo rm -rf || true",
                    "sudo find ~/Library/Application\\ Support -name 'com.adobe*' ! -name '*Adobe Downloader*' ! -path '*/Adobe Downloader/*' -print0 | xargs -0 sudo rm -rf || true",
                    "sudo rm -rf ~/Library/Application Support/io.branch",
                    "sudo rm -rf ~/Library/PhotoshopCrashes",
                    "sudo rm -rf ~/Library/WebKit/com.adobe*"
                ]
            case .adobePreferences:
                return [
                    "sudo find /Library/Preferences -name 'com.adobe*' ! -name '*Adobe Downloader*' -print0 | xargs -0 sudo rm -rf",
                    "sudo find ~/Library/Preferences -name 'com.adobe*' ! -name '*Adobe Downloader*' -print0 | xargs -0 sudo rm -rf",
                    "sudo find ~/Library/Preferences -name 'Adobe*' ! -name '*Adobe Downloader*' -print0 | xargs -0 sudo rm -rf",
                    "sudo find ~/Library/Preferences/ByHost -name 'com.adobe*' ! -name '*Adobe Downloader*' -print0 | xargs -0 sudo rm -rf",
                    "sudo rm -rf ~/Library/Preferences/adobe.com*",
                    "sudo rm -rf ~/Library/Preferences/AIRobin*",
                    "sudo rm -rf ~/Library/Preferences/Macromedia*",
                    "sudo rm -rf ~/Library/Saved Application State/com.adobe*"
                ]
            case .adobeCaches:
                return [
                    "sudo find ~/Library/Caches -name 'Adobe*' ! -name '*Adobe Downloader*' -print0 | xargs -0 sudo rm -rf || true",
                    "sudo find ~/Library/Caches -name 'com.adobe*' ! -name '*Adobe Downloader*' -print0 | xargs -0 sudo rm -rf || true",
                    "sudo rm -rf ~/Library/Caches/Acrobat* || true",
                    "sudo rm -rf ~/Library/Caches/CSXS || true",
                    "sudo rm -rf ~/Library/Caches/com.crashlytics.data/com.adobe* || true",
                    "sudo rm -rf ~/Library/Containers/com.adobe* || true",
                    "sudo rm -rf ~/Library/Cookies/com.adobe* || true",
                    "sudo find ~/Library/HTTPStorages -name '*Adobe*' ! -name '*Adobe Downloader*' ! -name '*com.x1a0he.macOS.Adobe-Downloader*' -print0 | xargs -0 sudo rm -rf || true",
                    "sudo find ~/Library/HTTPStorages -name 'com.adobe*' ! -name '*Adobe Downloader*' ! -name '*com.x1a0he.macOS.Adobe-Downloader*' -print0 | xargs -0 sudo rm -rf || true",
                    "sudo rm -rf ~/Library/HTTPStorages/Creative\\ Cloud\\ Content\\ Manager.node || true"
                ]
            case .adobeLicenses:
                return [
                    "sudo rm -rf /Library/Application Support/Adobe/Adobe PCD",
                    "sudo rm -rf /Library/Application Support/Adobe/AdobeGCClient",
                    "sudo rm -rf /Library/Application Support/regid.1986-12.com.adobe",
                    "sudo rm -rf /private/var/db/receipts/com.adobe*",
                    "sudo rm -rf /private/var/db/receipts/*Photoshop*",
                    "sudo rm -rf /private/var/db/receipts/*CreativeCloud*",
                    "sudo rm -rf /private/var/db/receipts/*CCXP*",
                    "sudo rm -rf /private/var/db/receipts/*mygreatcompany*",
                    "sudo rm -rf /private/var/db/receipts/*AntiCC*",
                    "sudo rm -rf /private/var/db/receipts/*.RiD.*",
                    "sudo rm -rf /private/var/db/receipts/*.CCRuntime.*"
                ]
            case .adobeLogs:
                return [
                    "sudo find ~/Library/Logs -name 'Adobe*' ! -name '*Adobe Downloader*' -print0 | xargs -0 sudo rm -rf",
                    "sudo find ~/Library/Logs -name 'adobe*' ! -name '*Adobe Downloader*' -print0 | xargs -0 sudo rm -rf",
                    "sudo rm -rf ~/Library/Logs/Adobe Creative Cloud Cleaner Tool.log",
                    "sudo rm -rf ~/Library/Logs/CreativeCloud",
                    "sudo rm -rf /Library/Logs/CreativeCloud",
                    "sudo rm -rf ~/Library/Logs/CSXS",
                    "sudo rm -rf ~/Library/Logs/amt3.log",
                    "sudo rm -rf ~/Library/Logs/CoreSyncInstall.log",
                    "sudo rm -rf ~/Library/Logs/CrashReporter/*Adobe*",
                    "sudo rm -rf ~/Library/Logs/acroLicLog.log",
                    "sudo rm -rf ~/Library/Logs/acroNGLLog.txt",
                    "sudo rm -rf ~/Library/Logs/DiagnosticReports/*Adobe*",
                    "sudo rm -rf ~/Library/Logs/distNGLLog.txt",
                    "sudo rm -rf ~/Library/Logs/NGL*",
                    "sudo rm -rf ~/Library/Logs/oobelib.log",
                    "sudo rm -rf ~/Library/Logs/PDApp*",
                    "sudo rm -rf /Library/Logs/adobe*",
                    "sudo rm -rf /Library/Logs/Adobe*",
                    "sudo rm -rf ~/Library/Logs/Adobe*",
                    "sudo rm -rf ~/Library/Logs/adobe*",
                    "sudo rm -rf /Library/Logs/DiagnosticReports/*Adobe*",
                    "sudo rm -rf /Library/Application Support/CrashReporter/*Adobe*",
                    "sudo rm -rf ~/Library/Application Support/CrashReporter/*Adobe*"
                ]
            case .adobeServices:
                return [
                    "sudo launchctl bootout gui/$(id -u) /Library/LaunchAgents/com.adobe.* || true",
                    "sudo launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/com.adobe.* || true",
                    "sudo launchctl unload /Library/LaunchDaemons/com.adobe.* || true",
                    "sudo launchctl remove com.adobe.AdobeCreativeCloud || true",
                    "sudo launchctl remove com.adobe.AdobeGenuineService.plist || true",
                    "sudo ps aux | grep -i 'Adobe' | grep -v 'Adobe Downloader' | grep -v 'Adobe-Downloader.helper' | grep -v grep | awk '{print $2}' | { pids=$(cat); [ ! -z \"$pids\" ] && echo \"$pids\" | xargs sudo kill -9; } || true",
                    "sudo rm -rf /Library/LaunchAgents/com.adobe.*",
                    "sudo rm -rf /Library/LaunchDaemons/com.adobe.*",
                    "sudo rm -rf /Library/LaunchAgents/com.adobe.ARMDCHelper*",
                    "sudo rm -rf /Library/LaunchAgents/com.adobe.AdobeCreativeCloud.plist",
                    "sudo rm -rf /Library/LaunchAgents/com.adobe.ccxprocess.plist"
                ]
            case .adobeKeychain:
                return [
                    "sudo security dump-keychain /Library/Keychains/System.keychain | grep -i 'acrobat.com' | grep -i 'srvr' | awk -F '=' '{print $2}' | cut -d '\"' -f2 | while read -r line; do sudo security delete-internet-password -s \"$line\" /Library/Keychains/System.keychain; done || true",
                    "sudo security dump-keychain ~/Library/Keychains/login.keychain-db | grep -i 'acrobat.com' | grep -i 'srvr' | awk -F '=' '{print $2}' | cut -d '\"' -f2 | while read -r line; do security delete-internet-password -s \"$line\" ~/Library/Keychains/login.keychain-db; done || true",
                    "sudo security dump-keychain /Library/Keychains/System.keychain | grep -i 'Adobe.APS' | grep -v 'Adobe Downloader' | awk -F '=' '{print $2}' | cut -d '\"' -f2 | while read -r line; do sudo security delete-generic-password -l \"$line\" /Library/Keychains/System.keychain; done || true",
                    "sudo security dump-keychain ~/Library/Keychains/login.keychain-db | grep -i 'Adobe.APS' | grep -v 'Adobe Downloader' | awk -F '=' '{print $2}' | cut -d '\"' -f2 | while read -r line; do security delete-generic-password -l \"$line\" ~/Library/Keychains/login.keychain-db; done || true",
                    "sudo security dump-keychain /Library/Keychains/System.keychain | grep -i 'Adobe App Info\\|Adobe App Prefetched Info\\|Adobe User\\|com.adobe\\|Adobe Lightroom' | grep -v 'Adobe Downloader' | grep -i 'svce' | awk -F '=' '{print $2}' | cut -d '\"' -f2 | while read -r line; do sudo security delete-generic-password -s \"$line\" /Library/Keychains/System.keychain; done || true",
                    "sudo security dump-keychain ~/Library/Keychains/login.keychain-db | grep -i 'Adobe App Info\\|Adobe App Prefetched Info\\|Adobe User\\|com.adobe\\|Adobe Lightroom' | grep -v 'Adobe Downloader' | grep -i 'svce' | awk -F '=' '{print $2}' | cut -d '\"' -f2 | while read -r line; do security delete-generic-password -s \"$line\" ~/Library/Keychains/login.keychain-db; done || true",
                    "sudo security dump-keychain /Library/Keychains/System.keychain | grep -i 'Adobe Content \\|Adobe Intermediate' | grep -v 'Adobe Downloader' | grep -i 'alis' | awk -F '=' '{print $2}' | cut -d '\"' -f2 | while read -r line; do sudo security delete-certificate -c \"$line\" /Library/Keychains/System.keychain; done || true",
                    "sudo security dump-keychain ~/Library/Keychains/login.keychain-db | grep -i 'Adobe Content \\|Adobe Intermediate' | grep -v 'Adobe Downloader' | grep -i 'alis' | awk -F '=' '{print $2}' | cut -d '\"' -f2 | while read -r line; do security delete-certificate -c \"$line\" ~/Library/Keychains/login.keychain-db; done || true"
                ]
            case .adobeGenuineService:
                return [
                    "sudo rm -rf /Library/Application Support/Adobe/Adobe Desktop Common/AdobeGenuineClient",
                    "sudo rm -rf /Library/Application Support/Adobe/AdobeGCClient",
                    "sudo rm -rf /Library/Preferences/com.adobe.AdobeGenuineService.plist",
                    "sudo rm -rf /Applications/Utilities/Adobe Creative Cloud/Utils/AdobeGenuineValidator",
                    "sudo rm -rf /Applications/Utilities/Adobe Genuine Service",
                    "sudo rm -rf /Library/PrivilegedHelperTools/com.adobe.acc*",
                    "sudo find /private/tmp -type d -iname '*adobe*' ! -iname '*Adobe Downloader*' -o -type f -iname '*adobe*' ! -iname '*Adobe Downloader*' | xargs rm -rf {} \\+",
                    "sudo find /private/tmp -type d -iname '*CCLBS*' ! -iname '*Adobe Downloader*' -o -type f -iname '*adobe*' ! -iname '*Adobe Downloader*' | xargs rm -rf {} \\+",
                    "sudo find /private/var/folders/ -type d -iname '*adobe*' ! -iname '*Adobe Downloader*' -o -type f -iname '*adobe*' ! -iname '*Adobe Downloader*' | xargs rm -rf {} \\+",
                    "sudo rm -rf /private/tmp/com.adobe*",
                    "sudo rm -rf /private/tmp/Adobe*",
                    "sudo rm -rf /private/tmp/.adobe*"
                ]
            case .adobeHosts:
                return [
                    "sudo sh -c 'grep -v \"adobe\" /etc/hosts > /etc/hosts.temp && mv /etc/hosts.temp /etc/hosts'"
                ]
            }
        }

        var description: String {
            switch self {
            case .adobeApps:
                return String(localized: "删除所有已安装的 Adobe 应用程序（不包括 Adobe Downloader）")
            case .adobeCreativeCloud:
                return String(localized: "删除 Adobe Creative Cloud 应用程序及其组件")
            case .adobePreferences:
                return String(localized: "删除 Adobe 应用程序的偏好设置文件（不包括 Adobe Downloader）")
            case .adobeCaches:
                return String(localized: "删除 Adobe 应用程序的缓存文件（不包括 Adobe Downloader）")
            case .adobeLicenses:
                return String(localized: "删除 Adobe 许可和激活相关文件")
            case .adobeLogs:
                return String(localized: "删除 Adobe 应用程序的日志文件（不包括 Adobe Downloader）")
            case .adobeServices:
                return String(localized: "停止并删除 Adobe 相关服务")
            case .adobeKeychain:
                return String(localized: "删除钥匙串中的 Adobe 相关条目")
            case .adobeGenuineService:
                return String(localized: "删除 Adobe 正版验证服务及其组件")
            case .adobeHosts:
                return String(localized: "清理 hosts 文件中的 Adobe 相关条目")
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading) {
            Text("选择要清理的内容")
                .font(.headline)
                .padding(.bottom, 4)

            Text("注意：清理过程不会影响 Adobe Downloader 的文件和下载数据")
                .font(.subheadline)
                .foregroundColor(.secondary)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading) {
                    ForEach(CleanupOption.allCases) { option in
                        VStack(spacing: 0) {
                            #if DEBUG
                            Button(action: {
                                withAnimation {
                                    if expandedOptions.contains(option) {
                                        expandedOptions.remove(option)
                                    } else {
                                        expandedOptions.insert(option)
                                    }
                                }
                            }) {
                                HStack(spacing: 12) {
                                    Toggle(isOn: Binding(
                                        get: { selectedOptions.contains(option) },
                                        set: { isSelected in
                                            if isSelected {
                                                selectedOptions.insert(option)
                                            } else {
                                                selectedOptions.remove(option)
                                            }
                                        }
                                    )) {
                                        EmptyView()
                                    }
                                    .toggleStyle(SwitchToggleStyle(tint: .green))
                                    .disabled(isProcessing)
                                    .labelsHidden()
                                    .scaleEffect(0.85)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(option.localizedName)
                                            .font(.system(size: 15, weight: .semibold))
                                        Text(option.description)
                                            .font(.system(size: 12))
                                            .foregroundColor(.secondary)
                                            .lineLimit(2)
                                    }

                                    Spacer()

                                    Image(systemName: expandedOptions.contains(option) ? "chevron.down" : "chevron.right")
                                        .foregroundColor(.secondary)
                                        .font(.system(size: 14, weight: .medium))
                                        .frame(width: 20, height: 20)
                                        .animation(.easeInOut, value: expandedOptions.contains(option))
                                }
                                .padding(.vertical, 10)
                                .padding(.horizontal, 10)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .disabled(isProcessing)

                            if expandedOptions.contains(option) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("将执行的命令：")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.secondary)
                                        .padding(.top, 2)
                                        .padding(.horizontal, 12)

                                    VStack(spacing: 6) {
                                        ForEach(option.commands, id: \.self) { command in
                                            Text(command)
                                                .font(.system(size: 11, design: .monospaced))
                                                .foregroundColor(Color(.white))
                                                .padding(10)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                                .background(Color.black.opacity(0.85))
                                                .cornerRadius(6)
                                        }
                                    }
                                    .padding(.horizontal, 12)
                                }
                                .padding(.bottom, 12)
                                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                            }
                            #else
                            HStack(spacing: 12) {
                                Toggle(isOn: Binding(
                                    get: { selectedOptions.contains(option) },
                                    set: { isSelected in
                                        if isSelected {
                                            selectedOptions.insert(option)
                                        } else {
                                            selectedOptions.remove(option)
                                        }
                                    }
                                )) {
                                    EmptyView()
                                }
                                .toggleStyle(SwitchToggleStyle(tint: .green))
                                .disabled(isProcessing)
                                .labelsHidden()
                                .scaleEffect(0.85)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(option.localizedName)
                                        .font(.system(size: 15, weight: .semibold))
                                    Text(option.description)
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                }

                                Spacer()
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 10)
                            #endif
                        }
                        .background(Color(NSColor.controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                    }
                }
            }

            Divider()
                .padding(.vertical, 8)

            VStack(alignment: .leading, spacing: 12) {
                if isProcessing {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("清理进度：\(currentCommandIndex)/\(totalCommands)")
                                .font(.system(size: 12, weight: .medium))
                            
                            Spacer()
                            
                            let percentage = totalCommands > 0 ? Int((Double(currentCommandIndex) / Double(totalCommands)) * 100) : 0
                            Text("\(percentage)%")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.blue)
                        }
                        .padding(.horizontal, 2)
                        
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.secondary.opacity(0.2))
                                    .frame(height: 12)
                                
                                let progressWidth = totalCommands > 0 ? 
                                    CGFloat(Double(currentCommandIndex) / Double(totalCommands)) * geometry.size.width : 0
                                
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [Color.blue.opacity(0.8), Color.blue]),
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: progressWidth, height: 12)
                            }
                        }
                        .frame(height: 12)
                        .animation(.linear(duration: 0.3), value: currentCommandIndex)
                        
                        Button(action: {
                            isCancelled = true
                        }) {
                            Text("取消清理")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white)
                        }
                        .buttonStyle(BeautifulButtonStyle(baseColor: Color.red.opacity(0.8)))
                        .disabled(isCancelled)
                        .opacity(isCancelled ? 0.5 : 1)
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(NSColor.controlBackgroundColor))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                    )

                    if let lastLog = cleanupLogs.last {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.triangle.turn.up.right.circle.fill")
                                    .foregroundColor(.blue.opacity(0.8))
                                    .font(.system(size: 14))
                                
                                Text("当前执行：")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                            
                            #if DEBUG
                            Text(lastLog.command)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                                .truncationMode(.middle)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            #else
                            Text(CleanupLog.getCleanupDescription(for: lastLog.command))
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                                .truncationMode(.middle)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            #endif
                        }
                        .frame(height: 70)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 8)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(NSColor.textBackgroundColor))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                        )
                    }
                }

                VStack(alignment: .leading, spacing: 0) {
                    Button(action: {
                        withAnimation {
                            isLogExpanded.toggle()
                        }
                    }) {
                        HStack {
                            Image(systemName: "terminal.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.blue.opacity(0.8))
                            
                            Text("最近日志：")
                                .font(.system(size: 12, weight: .medium))

                            if isProcessing {
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(Color.green)
                                        .frame(width: 6, height: 6)
                                    
                                    Text("正在执行...")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(4)
                            }

                            Spacer()

                            Text(isLogExpanded ? "收起" : "展开")
                                .font(.system(size: 11))
                                .foregroundColor(.blue)
                                .padding(.trailing, 4)
                                
                            Image(systemName: isLogExpanded ? "chevron.down" : "chevron.right")
                                .font(.system(size: 10))
                                .foregroundColor(.blue)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 10)
                        .background(Color(NSColor.controlBackgroundColor))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    ScrollView {
                        VStack(alignment: .leading, spacing: 8) {
                            if cleanupLogs.isEmpty {
                                HStack {
                                    Spacer()
                                    VStack(spacing: 6) {
                                        Image(systemName: "doc.text.magnifyingglass")
                                            .font(.system(size: 20))
                                            .foregroundColor(.secondary.opacity(0.6))
                                        
                                        Text("暂无清理记录")
                                            .font(.system(size: 11))
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.vertical, 16)
                                    Spacer()
                                }
                            } else {
                                if isLogExpanded {
                                    ForEach(cleanupLogs.reversed()) { log in
                                        LogEntryView(log: log)
                                    }
                                } else if let lastLog = cleanupLogs.last {
                                    LogEntryView(log: lastLog)
                                }
                            }
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 2)
                    }
                    .frame(height: cleanupLogs.isEmpty ? 80 : (isLogExpanded ? 220 : 54))
                    .animation(.easeInOut(duration: 0.3), value: isLogExpanded)
                    .background(Color(NSColor.textBackgroundColor).opacity(0.6))
                    .cornerRadius(6)
                    .padding(.bottom, 1)
                }
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(NSColor.textBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )
            }

            HStack(spacing: 10) {
                Group {
                    Button(action: {
                        selectedOptions = Set(CleanupOption.allCases)
                    }) {
                        Text("全选")
                            .frame(minWidth: 50)
                    }
                    .buttonStyle(BeautifulButtonStyle(baseColor: Color.blue.opacity(0.7)))
                    .foregroundColor(.white)

                    Button(action: {
                        selectedOptions.removeAll()
                    }) {
                        Text("取消全选")
                            .frame(minWidth: 65)
                    }
                    .buttonStyle(BeautifulButtonStyle(baseColor: Color.gray.opacity(0.7)))
                    .foregroundColor(.white)

                    #if DEBUG
                    Button(action: {
                        if expandedOptions.count == CleanupOption.allCases.count {
                            expandedOptions.removeAll()
                        } else {
                            expandedOptions = Set(CleanupOption.allCases)
                        }
                    }) {
                        Text(expandedOptions.count == CleanupOption.allCases.count ? "折叠全部" : "展开全部")
                            .frame(minWidth: 65)
                    }
                    .buttonStyle(BeautifulButtonStyle(baseColor: Color.purple.opacity(0.7)))
                    .foregroundColor(.white)
                    #endif
                }
                .disabled(isProcessing)
                
                Spacer()

                Button(action: {
                    if !selectedOptions.isEmpty {
                        showConfirmation = true
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "trash")
                        Text("开始清理")
                    }
                    .frame(minWidth: 100)
                }
                .buttonStyle(BeautifulButtonStyle(baseColor: Color.red.opacity(0.8)))
                .foregroundColor(.white)
                .opacity(selectedOptions.isEmpty || isProcessing ? 0.5 : 1)
                .saturation(selectedOptions.isEmpty || isProcessing ? 0.3 : 1)
                .disabled(selectedOptions.isEmpty || isProcessing)
            }
            .padding(.top, 6)
        }
        .padding()
        .alert("确认清理", isPresented: $showConfirmation) {
            Button("取消", role: .cancel) { }
            Button("确定", role: .destructive) {
                cleanupSelectedItems()
            }
        } message: {
            Text("这将删除所选的 Adobe 相关文件，该操作不可撤销。清理过程不会影响 Adobe Downloader 的文件和下载数据。是否继续？")
        }
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("清理结果"),
                message: Text(alertMessage),
                dismissButton: .default(Text("确定"))
            )
        }
    }

    private func cleanupSelectedItems() {
        isProcessing = true
        cleanupLogs.removeAll()
        currentCommandIndex = 0
        isCancelled = false

        let userHome = NSHomeDirectory()

        var commands: [String] = []
        for option in selectedOptions {
            let userCommands = option.commands.map { command in
                command.replacingOccurrences(of: "~/", with: "\(userHome)/")
            }
            commands.append(contentsOf: userCommands)
        }

        totalCommands = commands.count

        executeNextCommand(commands: commands)
    }

    private func executeNextCommand(commands: [String]) {
        guard currentCommandIndex < commands.count else {
            DispatchQueue.main.async {
                isProcessing = false
                alertMessage = isCancelled ? String(localized: "清理已取消") : String(localized: "清理完成")
                showAlert = true
                selectedOptions.removeAll()
            }
            return
        }

        if isCancelled {
            DispatchQueue.main.async {
                isProcessing = false
                alertMessage = String(localized: "清理已取消")
                showAlert = true
                selectedOptions.removeAll()
            }
            return
        }

        let command = commands[currentCommandIndex]
        cleanupLogs.append(CleanupLog(
            timestamp: Date(),
            command: command,
            status: .running,
            message: String(localized: "正在执行...")
        ))

        let timeoutTimer = DispatchSource.makeTimerSource(queue: .global())
        timeoutTimer.schedule(deadline: .now() + 30)
        timeoutTimer.setEventHandler { [self] in
            if let index = cleanupLogs.lastIndex(where: { $0.command == command }) {
                DispatchQueue.main.async {
                    cleanupLogs[index] = CleanupLog(
                        timestamp: Date(),
                        command: command,
                        status: .error,
                        message: String(localized: "执行结果：执行超时\n执行命令：\(command)")
                    )
                    currentCommandIndex += 1
                    executeNextCommand(commands: commands)
                }
            }
        }
        timeoutTimer.resume()

        PrivilegedHelperManager.shared.executeCommand(command) { [self] output in
            timeoutTimer.cancel()
            DispatchQueue.main.async {
                if let index = cleanupLogs.lastIndex(where: { $0.command == command }) {
                    if isCancelled {
                        cleanupLogs[index] = CleanupLog(
                            timestamp: Date(),
                            command: command,
                            status: .cancelled,
                            message: String(localized: "已取消")
                        )
                    } else {
                        let isSuccess = output.isEmpty || output.lowercased() == "success"
                        let message = if isSuccess {
                            String(localized: "执行成功")
                        } else {
                            String(localized: "执行结果：\(output)\n执行命令：\(command)")
                        }
                        cleanupLogs[index] = CleanupLog(
                            timestamp: Date(),
                            command: command,
                            status: isSuccess ? .success : .error,
                            message: message
                        )
                    }
                }
                currentCommandIndex += 1
                executeNextCommand(commands: commands)
            }
        }
    }

    private func statusIcon(for status: CleanupLog.LogStatus) -> String {
        switch status {
        case .running:
            return "arrow.triangle.2.circlepath"
        case .success:
            return "checkmark.circle.fill"
        case .error:
            return "exclamationmark.circle.fill"
        case .cancelled:
            return "xmark.circle.fill"
        }
    }

    private func statusColor(for status: CleanupLog.LogStatus) -> Color {
        switch status {
        case .running:
            return .blue
        case .success:
            return .green
        case .error:
            return .red
        case .cancelled:
            return .orange
        }
    }

    private func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}

struct LogEntryView: View {
    let log: CleanupLog
    @State private var showCopyButton = false

    var body: some View {
        HStack {
            Image(systemName: statusIcon(for: log.status))
                .foregroundColor(statusColor(for: log.status))

            Text(timeString(from: log.timestamp))
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            #if DEBUG
            Text(log.command)
                .font(.system(size: 11, design: .monospaced))
                .lineLimit(1)
                .truncationMode(.middle)
            #else
            Text(CleanupLog.getCleanupDescription(for: log.command))
                .font(.system(size: 11))
                .lineLimit(1)
                .truncationMode(.middle)
            #endif

            Spacer()

            if log.status == .error && !log.message.isEmpty {
                HStack(spacing: 4) {
                    Text(truncatedErrorMessage(log.message))
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    Button(action: {
                        copyToClipboard(log.message)
                    }) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                    .help("复制完整错误信息")
                }
            } else {
                Text(log.message)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
    }

    private func truncatedErrorMessage(_ message: String) -> String {
        if message.hasPrefix("执行失败：") {
            let errorMessage = String(message.dropFirst(5))
            if errorMessage.count > 30 {
                return "执行失败：" + errorMessage.prefix(30) + "..."
            }
        }
        return message
    }

    private func copyToClipboard(_ message: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(message, forType: .string)
    }

    private func statusIcon(for status: CleanupLog.LogStatus) -> String {
        switch status {
        case .running:
            return "arrow.triangle.2.circlepath"
        case .success:
            return "checkmark.circle.fill"
        case .error:
            return "exclamationmark.circle.fill"
        case .cancelled:
            return "xmark.circle.fill"
        }
    }

    private func statusColor(for status: CleanupLog.LogStatus) -> Color {
        switch status {
        case .running:
            return .blue
        case .success:
            return .green
        case .error:
            return .red
        case .cancelled:
            return .orange
        }
    }

    private func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}
