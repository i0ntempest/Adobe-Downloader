//
//  Adobe Downloader
//
//  Created by X1a0He on 2024/10/30.
//

import SwiftUI

struct DownloadManagerView: View {
    @Environment(\.dismiss) private var dismiss
    
    @ObservedObject private var networkManager = globalNetworkManager
    @State private var sortOrder: SortOrder = .addTime

    enum SortOrder {
        case addTime
        case name
        case status
        
        var description: String {
            switch self {
            case .addTime: return String(localized: "按添加时间")
            case .name: return String(localized: "按名称")
            case .status: return String(localized: "按状态")
            }
        }
    }
    
    private func removeTask(_ task: NewDownloadTask) {
        Task { @MainActor in
            globalNetworkManager.removeTask(taskId: task.id)
        }
    }

    private func sortTasks(_ tasks: [NewDownloadTask]) -> [NewDownloadTask] {
        switch sortOrder {
        case .addTime:
            return tasks
        case .name:
            return tasks.sorted { task1, task2 in
                task1.displayName < task2.displayName
            }
        case .status:
            return tasks.sorted { task1, task2 in
                task1.status.sortOrder < task2.status.sortOrder
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            DownloadManagerToolbar(
                sortOrder: $sortOrder,
                dismiss: dismiss
            )
            DownloadTaskList(
                tasks: sortTasks(networkManager.downloadTasks),
                removeTask: removeTask
            )
        }
        .background(Color(.clear))
        .frame(width:750, height: 500)
    }
}

private struct DownloadManagerToolbar: View {
    @Binding var sortOrder: DownloadManagerView.SortOrder
    let dismiss: DismissAction
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("下载管理")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                SortMenuView(sortOrder: $sortOrder)
                    .frame(minWidth: 120)
                    .fixedSize()
                
                ToolbarButtons(dismiss: dismiss)
            }
            .padding(.horizontal)
            .padding(.vertical, 14)
            
            Divider()
        }
        .background(Color(NSColor.clear))
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

private struct ToolbarButtons: View {
    let dismiss: DismissAction
    @State private var showClearCompletedConfirmation = false
    
    var body: some View {
        HStack(spacing: 12) {
            Button(action: {
                Task {
                    for task in globalNetworkManager.downloadTasks {
                        if case .downloading = task.status {
                            await globalNewDownloadUtils.pauseDownloadTask(
                                taskId: task.id,
                                reason: .userRequested
                            )
                        }
                    }
                }
            }) {
                Image(systemName: "pause.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.white)
            }
            .buttonStyle(BeautifulButtonStyle(baseColor: .orange))
            
            Button(action: {
                Task {
                    for task in globalNetworkManager.downloadTasks {
                        if case .paused = task.status {
                            await globalNewDownloadUtils.resumeDownloadTask(taskId: task.id)
                        }
                    }
                }
            }) {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.white)
            }
            .buttonStyle(BeautifulButtonStyle(baseColor: .blue))
            
            Button(action: {
                showClearCompletedConfirmation = true
            }) {
                Image(systemName: "trash.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.white)
            }
            .buttonStyle(BeautifulButtonStyle(baseColor: .red))
            
            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.white)
            }
            .buttonStyle(BeautifulButtonStyle(baseColor: .gray))
        }
        .background(Color(NSColor.clear))
        .alert("确认删除", isPresented: $showClearCompletedConfirmation) {
            Button("取消", role: .cancel) { }
            Button("确认", role: .destructive) {
                Task {
                    let tasksToRemove = globalNetworkManager.downloadTasks.filter { task in
                        if case .completed = task.status { return true }
                        if case .failed = task.status { return true }
                        return false
                    }
                    
                    for task in tasksToRemove {
                        globalNetworkManager.removeTask(taskId: task.id, removeFiles: true)
                    }
                    
                    globalNetworkManager.updateDockBadge()
                }
            }
        } message: {
            Text("确定要删除所有已完成和失败的下载任务吗？此操作将同时删除本地文件。")
        }
    }
}

private struct DownloadTaskList: View {
    let tasks: [NewDownloadTask]
    let removeTask: (NewDownloadTask) -> Void
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 8) {
                ForEach(tasks) { task in
                    DownloadProgressView(
                        task: task,
                        onCancel: { TaskOperations.cancelTask(task) },
                        onPause: { TaskOperations.pauseTask(task) },
                        onResume: { TaskOperations.resumeTask(task) },
                        onRetry: { TaskOperations.resumeTask(task) },
                        onRemove: { removeTask(task) }
                    )
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color(NSColor.clear))
    }
}

private enum TaskOperations {
    static func cancelTask(_ task: NewDownloadTask) {
        Task {
            await globalNewDownloadUtils.cancelDownloadTask(taskId: task.id)
        }
    }
    
    static func pauseTask(_ task: NewDownloadTask) {
        Task {
            await globalNewDownloadUtils.pauseDownloadTask(
                taskId: task.id,
                reason: .userRequested
            )
        }
    }
    
    static func resumeTask(_ task: NewDownloadTask) {
        Task {
            await globalNewDownloadUtils.resumeDownloadTask(taskId: task.id)
        }
    }
}

extension DownloadManagerView.SortOrder: Hashable {}

struct SortMenuView: View {
    @Binding var sortOrder: DownloadManagerView.SortOrder
    
    var body: some View {
        Menu {
            ForEach([DownloadManagerView.SortOrder.addTime, .name, .status], id: \.self) { order in
                Button(action: {
                    sortOrder = order
                }) {
                    HStack {
                        Text(order.description)
                            .font(.system(size: 14, weight: .medium))
                        Spacer()
                        if sortOrder == order {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                                .font(.system(size: 12, weight: .bold))
                        }
                    }
                    .frame(minWidth: 120)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                sortOrder == order ? Color.blue.opacity(0.05) : Color.clear,
                                sortOrder == order ? Color.blue.opacity(0.1) : Color.clear
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "arrow.up.arrow.down")
                    .font(.system(size: 12))
                Text(sortOrder.description)
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundColor(.white)
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.blue.opacity(0.7),
                        Color.blue.opacity(0.8)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
        }
        .menuStyle(BorderlessButtonMenuStyle())
        .menuIndicator(.hidden)
        .fixedSize()
    }
}

#Preview {
    DownloadManagerView()
}
