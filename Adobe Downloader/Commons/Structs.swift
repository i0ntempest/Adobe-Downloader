////
////  Adobe Downloader
////
////  Created by X1a0He on 2024/10/30.
////
//import Foundation
//
//
//class ProductsToDownload: ObservableObject, Codable {
//    var sapCode: String
//    var version: String
//    var buildGuid: String
//    var applicationJson: String?
//    @Published var packages: [Package] = []
//    @Published var completedPackages: Int = 0
//    
//    var totalPackages: Int {
//        packages.count
//    }
//
//    init(sapCode: String, version: String, buildGuid: String, applicationJson: String = "") {
//        self.sapCode = sapCode
//        self.version = version
//        self.buildGuid = buildGuid
//        self.applicationJson = applicationJson
//    }
//    
//    func updateCompletedPackages() {
//        Task { @MainActor in
//            completedPackages = packages.filter { $0.downloaded }.count
//            objectWillChange.send()
//        }
//    }
//
//    enum CodingKeys: String, CodingKey {
//        case sapCode, version, buildGuid, applicationJson, packages
//    }
//
//    func encode(to encoder: Encoder) throws {
//        var container = encoder.container(keyedBy: CodingKeys.self)
//        try container.encode(sapCode, forKey: .sapCode)
//        try container.encode(version, forKey: .version)
//        try container.encode(buildGuid, forKey: .buildGuid)
//        try container.encodeIfPresent(applicationJson, forKey: .applicationJson)
//        try container.encode(packages, forKey: .packages)
//    }
//
//    required init(from decoder: Decoder) throws {
//        let container = try decoder.container(keyedBy: CodingKeys.self)
//        sapCode = try container.decode(String.self, forKey: .sapCode)
//        version = try container.decode(String.self, forKey: .version)
//        buildGuid = try container.decode(String.self, forKey: .buildGuid)
//        applicationJson = try container.decodeIfPresent(String.self, forKey: .applicationJson)
//        packages = try container.decode([Package].self, forKey: .packages)
//        completedPackages = 0
//    }
//}
//
//struct SapCodes: Identifiable {
//    var id: String { sapCode }
//    var sapCode: String
//    var displayName: String
//}
//
//struct Sap: Codable, Equatable {
//    var id: String { sapCode }
//    var hidden: Bool
//    var displayName: String
//    var sapCode: String
//    var versions: [String: Versions]
//    var icons: [ProductIcon]
//    var productsToDownload: [ProductsToDownload]? = nil
//
//    enum CodingKeys: String, CodingKey {
//        case hidden, displayName, sapCode, versions, icons
//    }
//
//    static func == (lhs: Sap, rhs: Sap) -> Bool {
//        return lhs.sapCode == rhs.sapCode &&
//               lhs.hidden == rhs.hidden &&
//               lhs.displayName == rhs.displayName &&
//               lhs.versions == rhs.versions &&
//               lhs.icons == rhs.icons
//    }
//
//    struct Versions: Codable, Equatable {
//        var sapCode: String
//        var baseVersion: String
//        var productVersion: String
//        var apPlatform: String
//        var dependencies: [Dependencies]
//        var buildGuid: String
//        
//        struct Dependencies: Codable, Equatable {
//            var sapCode: String
//            var version: String
//        }
//    }
//    
//    struct ProductIcon: Codable, Equatable {
//        let size: String
//        let url: String
//        
//        var dimension: Int {
//            let components = size.split(separator: "x")
//            if components.count == 2,
//               let dimension = Int(components[0]) {
//                return dimension
//            }
//            return 0
//        }
//    }
//    
//    var isValid: Bool { !hidden }
//    
//    func getBestIcon() -> ProductIcon? {
//        if let icon = icons.first(where: { $0.size == "192x192" }) {
//            return icon
//        }
//        return icons.max(by: { $0.dimension < $1.dimension })
//    }
//
//    func hasValidVersions(allowedPlatform: [String]) -> Bool {
//        if hidden { return false }
//        
//        for version in Array(versions.values).reversed() {
//            if !version.buildGuid.isEmpty && 
//               (!version.buildGuid.contains("/") || sapCode == "APRO") &&
//               allowedPlatform.contains(version.apPlatform) {
//                return true
//            }
//        }
//        return false
//    }
//}
//
//
//struct ProductsResponse: Codable {
//    let products: [String: Sap]
//    let cdn: String
//}
