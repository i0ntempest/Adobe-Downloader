//
//  Adobe Downloader
//
//  Created by X1a0He on 2024/10/30.
//

import SwiftUI

struct DownloadManagerView: View {
    @Environment(\.dismiss) private var dismiss
    
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
        globalNetworkManager.removeTask(taskId: task.id)
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
                tasks: sortTasks(globalNetworkManager.downloadTasks),
                removeTask: removeTask
            )
        }
        .frame(width:800, height: 600)
    }
}

private struct DownloadManagerToolbar: View {
    @Binding var sortOrder: DownloadManagerView.SortOrder
    let dismiss: DismissAction
    
    var body: some View {
        HStack {
            Text("下载管理")
                .font(.headline)
            Spacer()
            SortMenuView(sortOrder: $sortOrder)
                .frame(minWidth: 120)
                .fixedSize()

            ToolbarButtons(dismiss: dismiss)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

private struct ToolbarButtons: View {
    let dismiss: DismissAction
    
    var body: some View {
        Group {
            Button("全部暂停") {
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
            }
            
            Button("全部继续") {
                Task {
                    for task in globalNetworkManager.downloadTasks {
                        if case .paused = task.status {
                            await globalNewDownloadUtils.resumeDownloadTask(taskId: task.id)
                        }
                    }
                }
            }
            
            Button("清理已完成") {
                globalNetworkManager.downloadTasks.removeAll { task in
                    if case .completed = task.status {
                        return true
                    }
                    return false
                }
                globalNetworkManager.updateDockBadge()
            }
            
            Button("关闭") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
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
        .background(Color(NSColor.windowBackgroundColor))
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
                        if sortOrder == order {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack {
                Image(systemName: "arrow.up.arrow.down")
                Text(sortOrder.description)
                    .font(.caption)
            }
        }
    }
}

#Preview {
    DownloadManagerView()
}
