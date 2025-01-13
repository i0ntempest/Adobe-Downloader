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
    
    private let sap: Sap
    private let onSelect: (String) -> Void
    
    init(sap: Sap, onSelect: @escaping (String) -> Void) {
        self.sap = sap
        self.onSelect = onSelect
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HeaderView(sap: sap, downloadAppleSilicon: downloadAppleSilicon)
            VersionListView(
                sap: sap,
                expandedVersions: $expandedVersions,
                onSelect: onSelect,
                dismiss: dismiss
            )
        }
        .frame(width: VersionPickerConstants.viewWidth, height: VersionPickerConstants.viewHeight)
    }
}

private struct HeaderView: View {
    let sap: Sap
    let downloadAppleSilicon: Bool
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var networkManager: NetworkManager
    
    var body: some View {
        VStack {
            HStack {
                Text("\(sap.displayName)")
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
    let sap: Sap
    @Binding var expandedVersions: Set<String>
    let onSelect: (String) -> Void
    let dismiss: DismissAction
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: VersionPickerConstants.verticalSpacing) {
                ForEach(filteredVersions, id: \.key) { version, info in
                    VersionRow(
                        sap: sap,
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
    
    private var filteredVersions: [(key: String, value: Sap.Versions)] {
        sap.versions
            .filter { StorageData.shared.allowedPlatform.contains($0.value.apPlatform) }
            .sorted { compareVersions($0.key, $1.key) > 0 }
    }
    
    private func compareVersions(_ version1: String, _ version2: String) -> Int {
        let components1 = version1.split(separator: ".").map { Int($0) ?? 0 }
        let components2 = version2.split(separator: ".").map { Int($0) ?? 0 }
        
        let maxLength = max(components1.count, components2.count)
        let paddedComponents1 = components1 + Array(repeating: 0, count: maxLength - components1.count)
        let paddedComponents2 = components2 + Array(repeating: 0, count: maxLength - components2.count)
        
        for i in 0..<maxLength {
            if paddedComponents1[i] != paddedComponents2[i] {
                return paddedComponents1[i] - paddedComponents2[i]
            }
        }
        return 0
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
    @EnvironmentObject private var networkManager: NetworkManager
    @StorageValue(\.defaultLanguage) private var defaultLanguage
    
    let sap: Sap
    let version: String
    let info: Sap.Versions
    let isExpanded: Bool
    let onSelect: (String) -> Void
    let onToggle: (String) -> Void
    
    private var existingPath: URL? {
        networkManager.isVersionDownloaded(
            sap: sap,
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
        if info.dependencies.isEmpty {
            onSelect(version)
        } else {
            onToggle(version)
        }
    }
}

private struct VersionHeader: View {
    let version: String
    let info: Sap.Versions
    let isExpanded: Bool
    let hasExistingPath: Bool
    let onSelect: () -> Void
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                VersionInfo(version: version, platform: info.apPlatform)
                Spacer()
                ExistingPathButton(isVisible: hasExistingPath)
                ExpandButton(
                    isExpanded: isExpanded,
                    hasDependencies: !info.dependencies.isEmpty
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
    let hasDependencies: Bool
    
    var body: some View {
        Image(systemName: iconName)
            .foregroundColor(.secondary)
    }
    
    private var iconName: String {
        if !hasDependencies {
            return "chevron.right"
        }
        return isExpanded ? "chevron.down" : "chevron.right"
    }
}

private struct VersionDetails: View {
    let info: Sap.Versions
    let version: String
    let onSelect: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: VersionPickerConstants.verticalSpacing) {
            Text("依赖包:")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 8)
                .padding(.leading, 16)
            
            DependenciesList(dependencies: info.dependencies)
            
            DownloadButton(version: version, onSelect: onSelect)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 8)
    }
}

private struct DependenciesList: View {
    let dependencies: [Sap.Versions.Dependencies]
    
    var body: some View {
        ForEach(dependencies, id: \.sapCode) { dependency in
            HStack(spacing: 8) {
                Image(systemName: "cube.box")
                    .foregroundColor(.blue)
                    .frame(width: 16)
                Text("\(dependency.sapCode) (\(dependency.version))")
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

struct VersionPickerView_Previews: PreviewProvider {
    static var previews: some View {
        let networkManager = NetworkManager()
        networkManager.cdn = "https://example.cdn.adobe.com"
        
        let previewSap = Sap(
            hidden: false,
            displayName: "Photoshop",
            sapCode: "PHSP",
            versions: [
                "26.0.0": Sap.Versions(
                    sapCode: "PHSP",
                    baseVersion: "26.0.0",
                    productVersion: "26.0.0",
                    apPlatform: "macuniversal",
                    dependencies: [
                        Sap.Versions.Dependencies(sapCode: "ACR", version: "9.6"),
                        Sap.Versions.Dependencies(sapCode: "COCM", version: "1.0"),
                        Sap.Versions.Dependencies(sapCode: "COSY", version: "2.4.1")
                    ],
                    buildGuid: "b382ef03-c44a-4fd4-a9a1-3119ab0474b4"
                ),
                "25.0.0": Sap.Versions(
                    sapCode: "PHSP",
                    baseVersion: "25.0.0",
                    productVersion: "25.0.0",
                    apPlatform: "macuniversal",
                    dependencies: [
                        Sap.Versions.Dependencies(sapCode: "ACR", version: "9.5"),
                        Sap.Versions.Dependencies(sapCode: "COCM", version: "1.0")
                    ],
                    buildGuid: "a1b2c3d4-e5f6-g7h8-i9j0-k1l2m3n4o5p6"
                ),
                "24.0.0": Sap.Versions(
                    sapCode: "PHSP",
                    baseVersion: "24.0.0",
                    productVersion: "24.0.0",
                    apPlatform: "macuniversal",
                    dependencies: [],
                    buildGuid: "q1w2e3r4-t5y6-u7i8-o9p0-a1s2d3f4g5h6"
                )
            ],
            icons: []
        )
        
        return VersionPickerView(sap: previewSap) { _ in }
            .environmentObject(networkManager)
            .previewDisplayName("Version Picker")
    }
}
