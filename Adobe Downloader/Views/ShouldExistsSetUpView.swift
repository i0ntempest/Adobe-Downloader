//
//  ShouldExistsSetUpView.swift
//  Adobe Downloader
//
//  Created by X1a0He on 11/11/24.
//

import SwiftUI

struct ShouldExistsSetUpView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var networkManager: NetworkManager
    @State private var showingAlert = false
    @State private var isDownloading = false
    @State private var downloadProgress: Double = 0
    @State private var downloadStatus: String = ""
    @State private var isCancelled = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""

    var body: some View {
        VStack(spacing: 20) {
            SetupAlertHeaderView()
            MessageView()
            ButtonsView(
                isDownloading: $isDownloading,
                downloadProgress: $downloadProgress,
                downloadStatus: $downloadStatus,
                isCancelled: $isCancelled,
                showingAlert: $showingAlert,
                showErrorAlert: $showErrorAlert,
                errorMessage: $errorMessage,
                dismiss: dismiss,
                networkManager: networkManager
            )
        }
        .frame(width: 500)
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(12)
        .shadow(radius: 10)
        .alert("下载失败", isPresented: $showErrorAlert) {
            Button("确定") { }
        } message: {
            Text(errorMessage)
        }
    }
}

private struct SetupAlertHeaderView: View {
    var body: some View {
        VStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 64))
                .foregroundColor(.orange)
                .padding(.bottom, 5)
                .frame(alignment: .bottomTrailing)

            Text("未检测到 Adobe CC 组件")
                .font(.system(size: 24))
                .bold()
        }
    }
}

private struct MessageView: View {
    var body: some View {
        VStack(spacing: 4) {
            Text("程序检测到你的系统中不存在 Adobe CC 组件")
                .multilineTextAlignment(.center)
            
            Text("可能导致无法使用安装功能，请确保是否使用安装功能")
                .multilineTextAlignment(.center)
        }
    }
}

private struct ButtonsView: View {
    @Binding var isDownloading: Bool
    @Binding var downloadProgress: Double
    @Binding var downloadStatus: String
    @Binding var isCancelled: Bool
    @Binding var showingAlert: Bool
    @Binding var showErrorAlert: Bool
    @Binding var errorMessage: String
    let dismiss: DismissAction
    let networkManager: NetworkManager

    var body: some View {
        VStack(spacing: 16) {
            notUseButton
            downloadButton
            creativeCloudButton
            exitButton
        }
    }
    
    private var notUseButton: some View {
        Button(action: { showingAlert = true }) {
            Label("不使用安装功能", systemImage: "exclamationmark.triangle.fill")
                .frame(minWidth: 0, maxWidth: 360)
                .frame(height: 32)
                .font(.system(size: 14))
        }
        .buttonStyle(.borderedProminent)
        .tint(.orange)
        .alert("确认", isPresented: $showingAlert) {
            Button("取消", role: .cancel) { }
            Button("确定", role: .destructive) {
                dismiss()
            }
        } message: {
            Text("你确定不使用安装功能吗？")
        }
        .disabled(isDownloading)
    }
    
    private var downloadButton: some View {
        Button(action: startDownload) {
            if isDownloading {
                downloadProgressView
            } else {
                Label("下载 X1a0He CC", systemImage: "arrow.down")
                    .frame(minWidth: 0, maxWidth: 360)
                    .frame(height: 32)
                    .font(.system(size: 14))
            }
        }
        .buttonStyle(.borderedProminent)
        .tint(.blue)
        .disabled(isDownloading)
    }
    
    private var downloadProgressView: some View {
        VStack {
            ProgressView(value: downloadProgress) {
                Text(downloadStatus)
                    .font(.system(size: 14))
            }
            Text("\(Int(downloadProgress * 100))%")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            Button("取消") {
                isCancelled = true
            }
            .buttonStyle(.borderless)
        }
        .frame(maxWidth: 360)
        .progressViewStyle(.linear)
        .tint(.green)
    }
    
    private var creativeCloudButton: some View {
        Button(action: openCreativeCloud) {
            Label("前往 Adobe Creative Cloud", systemImage: "cloud.fill")
                .frame(minWidth: 0, maxWidth: 360)
                .frame(height: 32)
                .font(.system(size: 14))
        }
        .disabled(isDownloading)
    }
    
    private var exitButton: some View {
        Button(action: exitApp) {
            Label("退出", systemImage: "xmark")
                .frame(minWidth: 0, maxWidth: 360)
                .frame(height: 32)
                .font(.system(size: 14))
        }
        .buttonStyle(.borderedProminent)
        .tint(.red)
        .keyboardShortcut(.cancelAction)
        .disabled(isDownloading)
    }
    
    private func startDownload() {
        isDownloading = true
        isCancelled = false
        Task {
            do {
                try await globalNewDownloadUtils.downloadX1a0HeCCPackages(
                    progressHandler: { progress, status in
                        Task { @MainActor in
                            downloadProgress = progress
                            downloadStatus = status
                        }
                    },
                    cancellationHandler: { isCancelled }
                )
                await MainActor.run {
                    dismiss()
                }
            } catch NetworkError.cancelled {
                await MainActor.run {
                    isDownloading = false
                }
            } catch {
                await MainActor.run {
                    isDownloading = false
                    errorMessage = error.localizedDescription
                    showErrorAlert = true
                }
            }
        }
    }
    
    private func openCreativeCloud() {
        if let url = URL(string: "https://creativecloud.adobe.com/apps/download/creative-cloud") {
            NSWorkspace.shared.open(url)
            dismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                NSApplication.shared.terminate(nil)
            }
        }
    }
    
    private func exitApp() {
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NSApplication.shared.terminate(nil)
        }
    }
}

#Preview {
    ShouldExistsSetUpView()
        .environmentObject(NetworkManager())
}
