import SwiftUI
import Sparkle

@main
struct Adobe_DownloaderApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var showBackupAlert = false
    @State private var showTipsSheet = false
    @State private var showLanguagePicker = false
    @State private var showCreativeCloudAlert = false
    @State private var showBackupResultAlert = false
    @State private var backupResultMessage = ""
    @State private var backupSuccess = false
    
    private var storage: StorageData { StorageData.shared }
    private let updaterController: SPUStandardUpdaterController

    init() {
        globalNetworkService = NewNetworkService()
        globalNetworkManager = NetworkManager()
        globalNewDownloadUtils = NewDownloadUtils()
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        
        if storage.installedHelperBuild == "0" {
            storage.installedHelperBuild = "0"
        }

        if storage.isFirstLaunch {
            initializeFirstLaunch()
        }

        if storage.apiVersion == "6" {
            storage.apiVersion = "6"
        }
    }
    
    private func initializeFirstLaunch() {
        storage.downloadAppleSilicon = AppStatics.isAppleSilicon
        storage.confirmRedownload = true
        
        let systemLanguage = Locale.current.identifier
        let matchedLanguage = AppStatics.supportedLanguages.first {
            systemLanguage.hasPrefix($0.code.prefix(2))
        }?.code ?? "ALL"
        storage.defaultLanguage = matchedLanguage
        storage.useDefaultLanguage = true
        
        if let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first {
            storage.defaultDirectory = downloadsURL.path
            storage.useDefaultDirectory = true
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(globalNetworkManager)
                .frame(minWidth: 792, minHeight: 600)
                .tint(.blue)
                .task {
                    await setupApplication()
                }
                .sheet(isPresented: $showCreativeCloudAlert) {
                    ShouldExistsSetUpView()
                        .environmentObject(globalNetworkManager)
                }
                .alert("Setup未备份提示", isPresented: $showBackupAlert) {
                    Button("确定") {
                        handleBackup()
                    }
                    Button("取消", role: .cancel) {}
                } message: {
                    Text("检测到Setup文件尚未备份，如果你需要安装程序，则Setup必须被处理，点击确定后你需要输入密码，Adobe Downloader将自动处理并备份为Setup.original")
                }
                .alert(backupSuccess ? "备份成功" : "备份失败", isPresented: $showBackupResultAlert) {
                    Button("确定") { }
                } message: {
                    Text(backupResultMessage)
                }
                .sheet(isPresented: $showTipsSheet) {
                    TipsSheetView(
                        showTipsSheet: $showTipsSheet,
                        showLanguagePicker: $showLanguagePicker
                    )
                    .environmentObject(globalNetworkManager)
                    .sheet(isPresented: $showLanguagePicker) {
                        LanguagePickerView(languages: AppStatics.supportedLanguages) { language in
                            storage.defaultLanguage = language
                            showLanguagePicker = false
                        }
                    }
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizabilityContentSize()
        .commands {
            CommandGroup(after: .appInfo) {
                CheckForUpdatesView(updater: updaterController.updater)
            }
        }

        Settings {
            AboutView(updater: updaterController.updater)
        }
    }
    
    private func setupApplication() async {
        PrivilegedHelperManager.shared.checkInstall()
        
        await MainActor.run {
            globalNetworkManager.loadSavedTasks()
        }

        let needsBackup = !ModifySetup.isSetupBackup()
        let needsSetup = !ModifySetup.isSetupExists()

        await MainActor.run {
            if needsSetup {
                showCreativeCloudAlert = true
            } else if needsBackup {
                #if !DEBUG
                showBackupAlert = true
                #endif
            }

            if storage.isFirstLaunch {
                showTipsSheet = true
                storage.isFirstLaunch = false
            }
        }
    }
    
    private func handleBackup() {
        ModifySetup.backupAndModifySetupFile { success, message in
            backupSuccess = success
            backupResultMessage = message
            showBackupResultAlert = true
        }
    }
}

extension Scene {
    func windowResizabilityContentSize() -> some Scene {
        if #available(macOS 13.0, *) {
            return windowResizability(.contentSize)
        } else {
            return self
        }
    }
}
