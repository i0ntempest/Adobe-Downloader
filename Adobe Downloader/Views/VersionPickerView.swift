//
//  Adobe Downloader
//
//  Created by X1a0He on 2024/10/30.
//
import SwiftUI


private enum VersionPickerConstants {
    static let headerPadding: CGFloat = 5
    static let viewWidth: CGFloat = 500
    static let viewHeight: CGFloat = 600
    static let iconSize: CGFloat = 32
    static let verticalSpacing: CGFloat = 8
    static let horizontalSpacing: CGFloat = 12
    static let cornerRadius: CGFloat = 8
    static let buttonPadding: CGFloat = 8
    
    static let titleFontSize: CGFloat = 14
    static let captionFontSize: CGFloat = 12
}

struct VersionPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @StorageValue(\.defaultLanguage) private var defaultLanguage
    @StorageValue(\.downloadAppleSilicon) private var downloadAppleSilicon
    @State private var expandedVersions: Set<String> = []
    
    private let productId: String
    private let onSelect: (String) -> Void
    
    init(productId: String, onSelect: @escaping (String) -> Void) {
        self.productId = productId
        self.onSelect = onSelect
    }
    
    var body: some View {
        VStack(spacing: 0) {
            VersionPickerHeaderView(productId: productId, downloadAppleSilicon: downloadAppleSilicon)
            VersionListView(
                productId: productId,
                expandedVersions: $expandedVersions,
                onSelect: onSelect,
                dismiss: dismiss
            )
        }
        .frame(width: VersionPickerConstants.viewWidth, height: VersionPickerConstants.viewHeight)
    }
}

private struct VersionPickerHeaderView: View {
    let productId: String
    let downloadAppleSilicon: Bool
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack {
            HStack {
                if let product = findProduct(id: productId) {
                    if let icon = product.getBestIcon() {
                        AsyncImage(url: URL(string: icon.value)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 24, height: 24)
                        } placeholder: {
                            Image(systemName: "app.fill")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 24, height: 24)
                                .foregroundColor(.blue)
                        }
                    }
                    
                    Text("\(product.displayName)")
                        .font(.headline)
                }
                Text("选择版本")
                    .foregroundColor(.secondary)
                Spacer()
                Button("取消") {
                    dismiss()
                }
                .buttonStyle(BeautifulButtonStyle(baseColor: Color.gray.opacity(0.2)))
            }
            .padding(.bottom, VersionPickerConstants.headerPadding)
            
            HStack(spacing: 6) {
                Image(systemName: downloadAppleSilicon ? "m.square" : "x.square")
                    .foregroundColor(.blue)
                Text(downloadAppleSilicon ? "Apple Silicon" : "Intel")
                    .font(.caption)
                    .fontWeight(.medium)
                Text("•")
                    .foregroundColor(.secondary)
                Text(platformText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
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
    let productId: String
    @Binding var expandedVersions: Set<String>
    let onSelect: (String) -> Void
    let dismiss: DismissAction
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                LazyVStack(spacing: VersionPickerConstants.verticalSpacing) {
                    ForEach(filteredVersions, id: \.key) { version, info in
                        VersionRow(
                            productId: productId,
                            version: version,
                            info: info,
                            isExpanded: expandedVersions.contains(version),
                            onSelect: handleVersionSelect,
                            onToggle: handleVersionToggle
                        )
                    }
                }
                .padding()

                HStack(spacing: 8) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(width: 6, height: 6)
                    Text("获取到 \(filteredVersions.count) 个版本")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 16)
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    private var filteredVersions: [(key: String, value: Product.Platform)] {
        let products = findProducts(id: productId)
        if products.isEmpty {
            return []
        }

        var versionPlatformMap: [String: Product.Platform] = [:]
        
        for product in products {
            let platforms = product.platforms.filter { platform in
                StorageData.shared.allowedPlatform.contains(platform.id)
            }
            
            if let firstPlatform = platforms.first {
                versionPlatformMap[product.version] = firstPlatform
            }
        }

        return versionPlatformMap.map { (key: $0.key, value: $0.value) }
            .sorted { pair1, pair2 in
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
    
    let productId: String
    let version: String
    let info: Product.Platform
    let isExpanded: Bool
    let onSelect: (String) -> Void
    let onToggle: (String) -> Void
    
    private var existingPath: URL? {
        globalNetworkManager.isVersionDownloaded(
            productId: productId,
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
                onSelect: { onToggle(version) },
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
}

private struct VersionHeader: View {
    let version: String
    let info: Product.Platform
    let isExpanded: Bool
    let hasExistingPath: Bool
    let onSelect: () -> Void
    let onToggle: () -> Void
    
    private var hasDependencies: Bool {
        !(info.languageSet.first?.dependencies.isEmpty ?? true)
    }
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                VersionInfo(version: version, platform: info.id, info: info)
                Spacer()
                ExistingPathButton(isVisible: hasExistingPath)
                ExpandButton(
                    isExpanded: isExpanded,
                    onToggle: onToggle,
                    hasDependencies: hasDependencies
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
    let info: Product.Platform
    
    private var productVersion: String? {
        info.languageSet.first?.productVersion
    }
    
    private var buildGuid: String? {
        info.languageSet.first?.buildGuid
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(version)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary.opacity(0.9))
                
                if let pv = productVersion, pv != version {
                    Text("•")
                        .foregroundColor(.secondary)
                    Text("v\(pv)")
                        .font(.system(size: 12))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.blue.opacity(0.1))
                        )
                        .foregroundColor(.blue.opacity(0.8))
                }
            }

            HStack(spacing: 4) {
                Text(platform)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary.opacity(0.8))
                
                if let guid = buildGuid {
                    Text("•")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Text(guid)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary.opacity(0.7))
                        .textSelection(.enabled)
                }
            }
        }
    }
}

private struct ExistingPathButton: View {
    let isVisible: Bool
    
    var body: some View {
        if isVisible {
            Text("已存在")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.blue.opacity(0.9))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.blue.opacity(0.1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(Color.blue.opacity(0.2), lineWidth: 0.5)
                )
        }
    }
}

private struct ExpandButton: View {
    let isExpanded: Bool
    let onToggle: () -> Void
    let hasDependencies: Bool
    
    var body: some View {
        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
            .foregroundColor(.secondary)
            .contentShape(Rectangle())
            .onTapGesture(perform: onToggle)
    }
}

private struct VersionDetails: View {
    let info: Product.Platform
    let version: String
    let onSelect: (String) -> Void
    
    private var hasDependencies: Bool {
        !(info.languageSet.first?.dependencies.isEmpty ?? true)
    }
    
    private var hasModules: Bool {
        !(info.modules.isEmpty)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: VersionPickerConstants.verticalSpacing) {
            if hasDependencies || hasModules {
                VStack(alignment: .leading, spacing: 8) {
                    if hasDependencies {
                        HStack(spacing: 5) {
                            Image(systemName: "shippingbox.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.blue.opacity(0.8))
                            Text("依赖组件")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                            Text("(\(info.languageSet.first?.dependencies.count ?? 0))")
                                .font(.system(size: 11))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color.blue.opacity(0.1))
                                )
                                .foregroundColor(.blue.opacity(0.8))
                        }
                        .padding(.vertical, 4)
                        DependenciesList(dependencies: info.languageSet.first?.dependencies ?? [])
                            .padding(.leading, 8)
                    }
                    #if DEBUG
                    if hasModules {
                        if hasDependencies {
                            Divider()
                                .padding(.vertical, 4)
                        }
                        
                        HStack(spacing: 5) {
                            Image(systemName: "square.stack.3d.up.fill")
                                .font(.system(size: 11))
                                .foregroundColor(.blue.opacity(0.8))
                            Text("可选模块")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                            Text("(\(info.modules.count))")
                                .font(.system(size: 11))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color.blue.opacity(0.1))
                                )
                                .foregroundColor(.blue.opacity(0.8))
                        }
                        .padding(.vertical, 4)
                        ModulesList(modules: info.modules)
                            .padding(.leading, 8)
                    }
                    #endif
                }
                .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                .cornerRadius(6)
            }
            
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
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    getPlatformIcon(for: dependency.selectedPlatform)
                        .foregroundColor(.blue.opacity(0.8))
                        .font(.system(size: 12))
                        .frame(width: 16)
                    
                    Text(dependency.sapCode)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.primary.opacity(0.8))
                    
                    Text("\(dependency.productVersion)")
                        .font(.system(size: 11))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color.blue.opacity(0.1))
                        )
                        .foregroundColor(.blue.opacity(0.8))
                }
                .padding(.vertical, 2)

                HStack(spacing: 10) {
                    if dependency.baseVersion != dependency.productVersion {
                        HStack(spacing: 3) {
                            Text("base:")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary.opacity(0.7))
                            Text(dependency.baseVersion)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.secondary.opacity(0.9))
                        }
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.secondary.opacity(0.07))
                        .cornerRadius(2)
                    }
                    
                    if !dependency.buildGuid.isEmpty {
                        HStack(spacing: 3) {
                            Text("buildGuid:")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary.opacity(0.7))
                            Text(dependency.buildGuid)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.secondary.opacity(0.9))
                                .textSelection(.enabled)
                        }
                    }
                }
                .padding(.top, 2)
                .padding(.leading, 24)
                
                #if DEBUG
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text("Match:")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(dependency.isMatchPlatform ? "✅" : "❌")
                            .font(.caption2)
                        
                        Text("•")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            
                        Text("Target:")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(dependency.targetPlatform)
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                    
                    if !dependency.selectedReason.isEmpty {
                        HStack(spacing: 4) {
                            Text("Reason:")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(dependency.selectedReason)
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }
                    }
                }
                .padding(.leading, 22)
                #endif
            }
            .padding(.vertical, 4)
        }
    }
    
    private func getPlatformIcon(for platform: String) -> Image {
        switch platform {
        case "macarm64":
            return Image(systemName: "m.square")
        case "macuniversal":
            return Image(systemName: "m.circle")
        case "osx10", "osx10-64":
            return Image(systemName: "x.square")
        default:
            return Image(systemName: "questionmark.square")
        }
    }
}

private struct ModulesList: View {
    let modules: [Product.Platform.Module]
    
    var body: some View {
        ForEach(modules, id: \.id) { module in
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.blue.opacity(0.3))
                    .frame(width: 6, height: 6)
                
                Text(module.displayName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary.opacity(0.8))
                
                if !module.deploymentType.isEmpty {
                    Text("(\(module.deploymentType))")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary.opacity(0.8))
                }
                
                Spacer()
            }
            .padding(.vertical, 3)
        }
    }
}

private struct DownloadButton: View {
    let version: String
    let onSelect: (String) -> Void
    
    var body: some View {
        Button("下载") {
            onSelect(version)
        }
        .foregroundColor(.white)
        .buttonStyle(BeautifulButtonStyle(baseColor: Color.blue))
        .padding(.top, 8)
    }
}
