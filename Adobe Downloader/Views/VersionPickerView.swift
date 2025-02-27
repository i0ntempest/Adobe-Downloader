//
//  Adobe Downloader
//
//  Created by X1a0He on 2024/10/30.
//
import SwiftUI


private enum VersionPickerConstants {
    static let headerPadding: CGFloat = 5
    static let viewWidth: CGFloat = 400
    static let viewHeight: CGFloat = 500
    static let iconSize: CGFloat = 32
    static let verticalSpacing: CGFloat = 8
    static let horizontalSpacing: CGFloat = 12
    static let cornerRadius: CGFloat = 8
    static let buttonPadding: CGFloat = 8
    
    static let titleFontSize: CGFloat = 14
    static let captionFontSize: CGFloat = 12
}

struct VersionPickerView: View {
    @EnvironmentObject private var networkManager: NetworkManager
    @Environment(\.dismiss) private var dismiss
    @StorageValue(\.defaultLanguage) private var defaultLanguage
    @StorageValue(\.downloadAppleSilicon) private var downloadAppleSilicon
    @State private var expandedVersions: Set<String> = []
    
    private let product: Product
    private let onSelect: (String) -> Void
    
    init(product: Product, onSelect: @escaping (String) -> Void) {
        self.product = product
        self.onSelect = onSelect
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HeaderView(product: product, downloadAppleSilicon: downloadAppleSilicon)
            VersionListView(
                product: product,
                expandedVersions: $expandedVersions,
                onSelect: onSelect,
                dismiss: dismiss
            )
        }
        .frame(width: VersionPickerConstants.viewWidth, height: VersionPickerConstants.viewHeight)
    }
}

private struct HeaderView: View {
    let product: Product
    let downloadAppleSilicon: Bool
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var networkManager: NetworkManager
    
    var body: some View {
        VStack {
            HStack {
                Text("\(product.displayName)")
                    .font(.headline)
                Text("选择版本")
                    .foregroundColor(.secondary)
                Spacer()
                Button("取消") {
                    dismiss()
                }
            }
            .padding(.bottom, VersionPickerConstants.headerPadding)
            
            Text("🔔 即将下载 \(downloadAppleSilicon ? "Apple Silicon" : "Intel") (\(platformText)) 版本 🔔")
                .font(.caption)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 10)
        }
        .padding(.horizontal)
        .padding(.top)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    private var platformText: String {
        StorageData.shared.allowedPlatform.joined(separator: ", ")
    }
}

private struct VersionListView: View {
    @EnvironmentObject private var networkManager: NetworkManager
    let product: Product
    @Binding var expandedVersions: Set<String>
    let onSelect: (String) -> Void
    let dismiss: DismissAction
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: VersionPickerConstants.verticalSpacing) {
                ForEach(filteredVersions, id: \.key) { version, info in
                    VersionRow(
                        product: product,
                        version: version,
                        info: info,
                        isExpanded: expandedVersions.contains(version),
                        onSelect: handleVersionSelect,
                        onToggle: handleVersionToggle
                    )
                }
            }
            .padding()
        }
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    private var filteredVersions: [(key: String, value: Product.Platform)] {
        // 获取支持的平台
        let platforms = product.platforms.filter { platform in
            StorageData.shared.allowedPlatform.contains(platform.id) && 
            platform.languageSet.first != nil
        }
        
        // 如果没有支持的平台，返回空数组
        if platforms.isEmpty {
            return []
        }
        
        // 将平台按版本号降序排序
        return platforms.map { platform in
            // 使用第一个语言集的 productVersion 作为版本号
            (key: platform.languageSet.first?.productVersion ?? "", value: platform)
        }.sorted { pair1, pair2 in
            // 按版本号降序排序
            AppStatics.compareVersions(pair1.key, pair2.key) > 0
        }
    }
    
    private func handleVersionSelect(_ version: String) {
        onSelect(version)
        dismiss()
    }
    
    private func handleVersionToggle(_ version: String) {
        withAnimation {
            if expandedVersions.contains(version) {
                expandedVersions.remove(version)
            } else {
                expandedVersions.insert(version)
            }
        }
    }
}

private struct VersionRow: View {
    @StorageValue(\.defaultLanguage) private var defaultLanguage
    
    let product: Product
    let version: String
    let info: Product.Platform
    let isExpanded: Bool
    let onSelect: (String) -> Void
    let onToggle: (String) -> Void
    
    private var existingPath: URL? {
        globalNetworkManager.isVersionDownloaded(
            product: product,
            version: version,
            language: defaultLanguage
        )
    }
    
    var body: some View {
        VStack(spacing: 0) {
            VersionHeader(
                version: version,
                info: info,
                isExpanded: isExpanded,
                hasExistingPath: existingPath != nil,
                onSelect: handleSelect,
                onToggle: { onToggle(version) }
            )
            
            if isExpanded {
                VersionDetails(
                    info: info,
                    version: version,
                    onSelect: onSelect
                )
            }
        }
        .padding(.horizontal)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(VersionPickerConstants.cornerRadius)
    }
    
    private func handleSelect() {
        let dependencies = info.languageSet.first?.dependencies ?? []
        if dependencies.isEmpty {
            onSelect(version)
        } else {
            onToggle(version)
        }
    }
}

private struct VersionHeader: View {
    let version: String
    let info: Product.Platform
    let isExpanded: Bool
    let hasExistingPath: Bool
    let onSelect: () -> Void
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                VersionInfo(version: version, platform: info.id)
                Spacer()
                ExistingPathButton(isVisible: hasExistingPath)
                ExpandButton(
                    isExpanded: isExpanded,
                    onToggle: onToggle,
                    hasDependencies: !(info.languageSet.first?.dependencies.isEmpty ?? true)
                )
            }
            .padding(.vertical, VersionPickerConstants.buttonPadding)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct VersionInfo: View {
    let version: String
    let platform: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(version)
                .font(.headline)
            Text(platform)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

private struct ExistingPathButton: View {
    let isVisible: Bool
    
    var body: some View {
        if isVisible {
            Text("可能已存在目录")
                .font(.caption)
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.blue)
                .cornerRadius(4)
        }
    }
}

private struct ExpandButton: View {
    let isExpanded: Bool
    let onToggle: () -> Void
    let hasDependencies: Bool
    
    var body: some View {
        Button(action: onToggle) {
            Image(systemName: iconName)
                .foregroundColor(.secondary)
        }
    }
    
    private var iconName: String {
        if !hasDependencies {
            return "chevron.right"
        }
        return isExpanded ? "chevron.down" : "chevron.right"
    }
}

private struct VersionDetails: View {
    let info: Product.Platform
    let version: String
    let onSelect: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: VersionPickerConstants.verticalSpacing) {
            Text("依赖包:")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 8)
                .padding(.leading, 16)
            
            DependenciesList(dependencies: info.languageSet.first?.dependencies ?? [])
            
            DownloadButton(version: version, onSelect: onSelect)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 8)
    }
}

private struct DependenciesList: View {
    let dependencies: [Product.Platform.LanguageSet.Dependency]

    var body: some View {
        ForEach(dependencies, id: \.sapCode) { dependency in
            HStack(spacing: 8) {
                Image(systemName: "cube.box")
                    .foregroundColor(.blue)
                    .frame(width: 16)
                Text("\(dependency.sapCode) (\(dependency.baseVersion))")
                    .font(.caption)
                Spacer()
            }
            .padding(.leading, 24)
        }
    }
}

private struct DownloadButton: View {
    let version: String
    let onSelect: (String) -> Void
    
    var body: some View {
        Button("下载此版本") {
            onSelect(version)
        }
        .buttonStyle(.borderedProminent)
        .padding(.top, 8)
        .padding(.leading, 16)
    }
}
