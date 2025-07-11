//
//  CustomDownloadView.swift
//  Adobe Downloader
//
//  Created by X1a0He on 2024/10/30.
//

import SwiftUI

struct CustomDownloadView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var loadingState = CustomDownloadLoadingState()
    @State private var allPackages: [Package] = []
    @State private var dependenciesToDownload: [DependenciesToDownload] = []
    
    let productId: String
    let version: String
    let onDownloadStart: ([DependenciesToDownload]) -> Void
    
    var body: some View {
        Group {
            if loadingState.isLoading {
                CustomDownloadLoadingView(
                    loadingState: loadingState,
                    productId: productId,
                    version: version
                )
            } else if loadingState.error != nil {
                VStack {
                    Text("加载失败")
                        .font(.headline)
                    Text(loadingState.error!)
                        .foregroundColor(.secondary)
                    Button("重试") {
                        loadingState.error = nil
                        loadingState.isLoading = true
                        loadPackageInfo()
                    }
                    .buttonStyle(BeautifulButtonStyle(baseColor: Color.blue))
                }
                .padding()
            } else {
                CustomPackageSelectorView(
                    productId: productId,
                    version: version,
                    packages: allPackages,
                    dependenciesToDownload: dependenciesToDownload,
                    onDownloadStart: { dependencies in
                        onDownloadStart(dependencies)
                        dismiss()
                    },
                    onCancel: { dismiss() }
                )
            }
        }
        .onAppear {
            if loadingState.isLoading {
                loadPackageInfo()
            }
        }
    }
    
    private func loadPackageInfo() {
        Task {
            do {
                let (packages, dependencies) = try await fetchPackageInfo()
                await MainActor.run {
                    allPackages = packages
                    dependenciesToDownload = dependencies
                    loadingState.isLoading = false
                }
            } catch {
                await MainActor.run {
                    loadingState.isLoading = false
                    loadingState.error = error.localizedDescription
                }
            }
        }
    }
    
    private func fetchPackageInfo() async throws -> ([Package], [DependenciesToDownload]) {
        guard let product = findProduct(id: productId) else {
            throw NetworkError.invalidData("找不到产品信息")
        }
        
        var allPackages: [Package] = []
        var dependenciesToDownload: [DependenciesToDownload] = []
        
        let firstPlatform = product.platforms.first
        let buildGuid = firstPlatform?.languageSet.first?.buildGuid ?? ""
        
        var dependencyInfos: [DependenciesToDownload] = []
        dependencyInfos.append(DependenciesToDownload(sapCode: product.id, version: product.version, buildGuid: buildGuid))
        
        let dependencies = firstPlatform?.languageSet.first?.dependencies
        if let dependencies = dependencies {
            for dependency in dependencies {
                dependencyInfos.append(DependenciesToDownload(sapCode: dependency.sapCode, version: dependency.productVersion, buildGuid: dependency.buildGuid))
            }
        }
        
        for dependencyInfo in dependencyInfos {
            await MainActor.run {
                loadingState.currentTask = "正在处理 \(dependencyInfo.sapCode) 的包信息..."
            }
            
            let jsonString = try await globalNetworkService.getApplicationInfo(buildGuid: dependencyInfo.buildGuid)
            dependencyInfo.applicationJson = jsonString
            
            var processedJsonString = jsonString
            if dependencyInfo.sapCode == product.id {
                if let jsonData = jsonString.data(using: .utf8),
                   var appInfo = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                    
                    if var modules = appInfo["Modules"] as? [String: Any] {
                        modules["Module"] = [] as [[String: Any]]
                        appInfo["Modules"] = modules
                    }
                    
                    if let processedData = try? JSONSerialization.data(withJSONObject: appInfo, options: .prettyPrinted),
                       let processedString = String(data: processedData, encoding: .utf8) {
                        processedJsonString = processedString
                    }
                }
            }
            
            guard let jsonData = processedJsonString.data(using: .utf8),
                  let appInfo = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                  let packages = appInfo["Packages"] as? [String: Any],
                  let packageArray = packages["Package"] as? [[String: Any]] else {
                throw NetworkError.invalidData("无法解析产品信息")
            }
            
            for package in packageArray {
                guard let downloadURL = package["Path"] as? String, !downloadURL.isEmpty else { continue }
                
                let packageVersion: String = package["PackageVersion"] as? String ?? ""
                let fullPackageName: String
                
                if let name = package["fullPackageName"] as? String, !name.isEmpty {
                    fullPackageName = name
                } else if let name = package["PackageName"] as? String, !name.isEmpty {
                    fullPackageName = "\(name).zip"
                } else {
                    continue
                }
                
                let downloadSize: Int64
                switch package["DownloadSize"] {
                case let sizeNumber as NSNumber:
                    downloadSize = sizeNumber.int64Value
                case let sizeString as String:
                    downloadSize = Int64(sizeString) ?? 0
                default:
                    downloadSize = 0
                }
                
                let packageType = package["Type"] as? String ?? "non-core"
                let condition = package["Condition"] as? String ?? ""
                
                // 判断是否应该默认选中这个包
                let isCore = packageType == "core"
                let targetArchitecture = StorageData.shared.downloadAppleSilicon ? "arm64" : "x64"
                let language = StorageData.shared.defaultLanguage
                let installLanguage = "[installLanguage]==\(language)"
                
                var shouldDefaultSelect = false
                var isRequired = false
                
                if dependencyInfo.sapCode == product.id {
                    if isCore {
                        shouldDefaultSelect = condition.isEmpty || 
                                            condition.contains("[OSArchitecture]==\(targetArchitecture)") ||
                                            condition.contains(installLanguage) || language == "ALL"
                        // 主产品的core包且满足条件的设为必需
                        isRequired = shouldDefaultSelect
                    } else {
                        shouldDefaultSelect = condition.contains(installLanguage) || language == "ALL"
                    }
                } else {
                    shouldDefaultSelect = condition.isEmpty ||
                                        (condition.contains("[OSVersion]") && checkOSVersionCondition(condition)) ||
                                        condition.contains(installLanguage) || language == "ALL"
                }
                
                let packageObj = Package(
                    type: packageType,
                    fullPackageName: fullPackageName,
                    downloadSize: downloadSize,
                    downloadURL: downloadURL,
                    packageVersion: packageVersion,
                    condition: condition,
                    isRequired: isRequired
                )

                packageObj.isSelected = shouldDefaultSelect
                
                dependencyInfo.packages.append(packageObj)
                allPackages.append(packageObj)
            }
            
            dependenciesToDownload.append(dependencyInfo)
        }
        
        return (allPackages, dependenciesToDownload)
    }
    
    private func checkOSVersionCondition(_ condition: String) -> Bool {
        let osVersion = ProcessInfo.processInfo.operatingSystemVersion
        let currentVersion = Double("\(osVersion.majorVersion).\(osVersion.minorVersion)") ?? 0.0
        
        let versionPattern = #"\[OSVersion\](>=|<=|<|>|==)([\d.]+)"#
        guard let regex = try? NSRegularExpression(pattern: versionPattern) else { return false }
        
        let nsRange = NSRange(condition.startIndex..<condition.endIndex, in: condition)
        let matches = regex.matches(in: condition, range: nsRange)
        
        for match in matches {
            guard match.numberOfRanges >= 3,
                  let operatorRange = Range(match.range(at: 1), in: condition),
                  let versionRange = Range(match.range(at: 2), in: condition),
                  let requiredVersion = Double(condition[versionRange]) else { continue }
            
            let operatorSymbol = String(condition[operatorRange])
            if !compareVersions(current: currentVersion, required: requiredVersion, operator: operatorSymbol) {
                return false
            }
        }
        
        return !matches.isEmpty
    }
    
    private func compareVersions(current: Double, required: Double, operator: String) -> Bool {
        switch `operator` {
        case ">=":
            return current >= required
        case "<=":
            return current <= required
        case ">":
            return current > required
        case "<":
            return current < required
        case "==":
            return current == required
        default:
            return false
        }
    }
}

class CustomDownloadLoadingState: ObservableObject {
    @Published var isLoading = true
    @Published var currentTask = ""
    @Published var error: String?
}

private struct CustomDownloadLoadingView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var loadingState: CustomDownloadLoadingState
    
    let productId: String
    let version: String
    
    var body: some View {
        VStack(spacing: 20) {
            VStack {
                if let product = findProduct(id: productId) {
                    HStack {
                        if let icon = product.getBestIcon() {
                            AsyncImage(url: URL(string: icon.value)) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 32, height: 32)
                            } placeholder: {
                                Image(systemName: "app.fill")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 32, height: 32)
                                    .foregroundColor(.blue)
                            }
                        }
                        
                        VStack(alignment: .leading) {
                            Text(product.displayName)
                                .font(.headline)
                            Text("版本 \(version)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                }
            }
            .padding()
            
            Divider()

            VStack(spacing: 15) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .frame(width: 40, height: 40)
                
                Text("正在获取包信息...")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                if !loadingState.currentTask.isEmpty {
                    Text(loadingState.currentTask)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            Spacer()

            HStack {
                Button("取消") {
                    dismiss()
                }
                .buttonStyle(BeautifulButtonStyle(baseColor: Color.gray.opacity(0.2)))
            }
            .padding()
        }
        .frame(width: 500, height: 400)
    }
}

private struct CustomPackageSelectorView: View {
    @State private var selectedPackages: Set<UUID> = []
    @State private var searchText = ""
    @State private var showCopiedAlert = false
    
    let productId: String
    let version: String
    let packages: [Package]
    let dependenciesToDownload: [DependenciesToDownload]
    let onDownloadStart: ([DependenciesToDownload]) -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("选择要下载的包")
                    .font(.headline)
                Spacer()

                Button(action: copyAllInfo) {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 12))
                        Text("复制全部")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(.white)
                }
                .buttonStyle(BeautifulButtonStyle(baseColor: Color.blue))
                .help("复制所有包信息")
                
                Button("取消") {
                    onCancel()
                }
                .buttonStyle(BeautifulButtonStyle(baseColor: Color.gray.opacity(0.2)))
            }
            .padding()
            
            Divider()

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(dependenciesToDownload, id: \.sapCode) { dependency in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                Image(systemName: "cube.box.fill")
                                    .font(.system(size: 13))
                                    .foregroundColor(.blue.opacity(0.8))
                                
                                Text("\(dependency.sapCode) \(dependency.version)\(dependency.sapCode != "APRO" ? " - (\(dependency.buildGuid))" : "")")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.primary.opacity(0.8))
                                    .textSelection(.enabled)
                                
                                if dependency.sapCode != "APRO" {
                                    Button(action: {
                                        copyToClipboard(dependency.buildGuid)
                                    }) {
                                        Image(systemName: "doc.on.doc")
                                            .font(.system(size: 10))
                                            .foregroundColor(.white)
                                    }
                                    .buttonStyle(BeautifulButtonStyle(baseColor: .blue))
                                    .help("复制 buildGuid")
                                }
                                
                                Spacer()
                            }
                            .padding(.horizontal)
                            .padding(.top, 8)

                            ForEach(dependency.packages) { package in
                                EnhancedPackageRow(
                                    package: package,
                                    isSelected: selectedPackages.contains(package.id),
                                    onToggle: { isSelected in
                                        if !package.isRequired {
                                            if isSelected {
                                                selectedPackages.insert(package.id)
                                            } else {
                                                selectedPackages.remove(package.id)
                                            }
                                        }
                                    },
                                    onCopyPackageInfo: {
                                        copyPackageInfo(package)
                                    }
                                )
                            }
                        }
                        .padding(.vertical, 4)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
                        .cornerRadius(8)
                    }
                }
                .padding()
            }
            
            Divider()

            HStack {
                Text("已选择 \(selectedPackages.count) 个包")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("总大小: \(formattedTotalSize)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button("开始下载") {
                    startCustomDownload()
                }
                .buttonStyle(BeautifulButtonStyle(baseColor: Color.blue))
                .disabled(selectedPackages.isEmpty)
            }
            .padding()
        }
        .frame(width: 800, height: 650)
        .onAppear {
            initializeSelection()
        }
        .popover(isPresented: $showCopiedAlert, arrowEdge: .trailing) {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("已复制")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }
    
    private var formattedTotalSize: String {
        let totalSize = selectedPackages.compactMap { id in
            packages.first { $0.id == id }?.downloadSize
        }.reduce(0, +)
        
        return ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }
    
    private func initializeSelection() {
        for package in packages {
            if package.isRequired || package.isSelected {
                selectedPackages.insert(package.id)
            }
        }
    }
    
    private func startCustomDownload() {
        for dependency in dependenciesToDownload {
            for package in dependency.packages {
                package.isSelected = selectedPackages.contains(package.id)
            }
        }

        let finalDependencies = dependenciesToDownload.filter { dependency in
            dependency.packages.contains { $0.isSelected }
        }
        
        onDownloadStart(finalDependencies)
    }
    
    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        showCopiedAlert = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            showCopiedAlert = false
        }
    }
    
    private func copyPackageInfo(_ package: Package) {
        let packageInfo = "\(package.fullPackageName) (\(package.packageVersion)) - \(package.type)"
        copyToClipboard(packageInfo)
    }
    
    private func copyAllInfo() {
        var result = ""

        for (index, dependency) in dependenciesToDownload.enumerated() {
            let dependencyInfo: String
            if dependency.sapCode == "APRO" {
                dependencyInfo = "\(dependency.sapCode) \(dependency.version)"
            } else {
                dependencyInfo = "\(dependency.sapCode) \(dependency.version) - (\(dependency.buildGuid))"
            }
            result += dependencyInfo + "\n"

            for (pkgIndex, package) in dependency.packages.enumerated() {
                let isLastPackage = pkgIndex == dependency.packages.count - 1
                let prefix = isLastPackage ? "    └── " : "    ├── "
                result += "\(prefix)\(package.fullPackageName) (\(package.packageVersion)) - \(package.type)\n"
            }

            if index < dependenciesToDownload.count - 1 {
                result += "\n"
            }
        }
        
        copyToClipboard(result)
    }
}

private struct EnhancedPackageRow: View {
    let package: Package
    let isSelected: Bool
    let onToggle: (Bool) -> Void
    let onCopyPackageInfo: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            Button(action: { 
                if !package.isRequired {
                    onToggle(!isSelected)
                }
            }) {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .foregroundColor(package.isRequired ? .secondary : .blue)
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(package.isRequired)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("\(package.fullPackageName) (\(package.packageVersion))")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.primary.opacity(0.8))
                        .textSelection(.enabled)

                    Text(package.type)
                        .font(.system(size: 10, weight: .medium))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 3)
                                .fill(package.type == "core" ? Color.blue.opacity(0.1) : Color.orange.opacity(0.1))
                        )
                        .foregroundColor(package.type == "core" ? .blue : .orange)
                    
                    if package.isRequired {
                        Text("必需")
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red.opacity(0.8))
                            .cornerRadius(4)
                    }
                    
                    Spacer()

                    Text(package.formattedSize)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    Button(action: onCopyPackageInfo) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 9))
                            .foregroundColor(.white)
                    }
                    .buttonStyle(BeautifulButtonStyle(baseColor: .gray.opacity(0.6)))
                    .help("复制包信息")
                }
                
                if !package.condition.isEmpty {
                    Text("条件: \(package.condition)")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary.opacity(0.8))
                        .textSelection(.enabled)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
        .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
        .overlay(
            Rectangle()
                .stroke(Color.secondary.opacity(0.2), lineWidth: 0.5)
                .opacity(0.5),
            alignment: .bottom
        )
    }
}
