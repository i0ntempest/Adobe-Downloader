//
//  Globals.swift
//  Adobe Downloader
//
//  Created by X1a0He on 2/26/25.
//

// 下面是所有全局变量的私有存储
private var _globalStiResult: NewParseResult?
private var _globalCcmResult: NewParseResult?
private var _globalProducts: [Product]?
private var _globalUniqueProducts: [UniqueProduct]?
private var _globalCdn: String = ""
private var _globalNetworkService: NewNetworkService?
private var _globalNetworkManager: NetworkManager?
private var _globalNewDownloadUtils: NewDownloadUtils?
private var _globalCancelTracker: CancelTracker?

// 计算属性，确保总是返回有效实例
var globalStiResult: NewParseResult {
    get {
        if _globalStiResult == nil {
            _globalStiResult = NewParseResult(products: [], cdn: "")
        }
        return _globalStiResult!
    }
    set {
        _globalStiResult = newValue
    }
}

var globalCcmResult: NewParseResult {
    get {
        if _globalCcmResult == nil {
            _globalCcmResult = NewParseResult(products: [], cdn: "")
        }
        return _globalCcmResult!
    }
    set {
        _globalCcmResult = newValue
    }
}

var globalCdn: String {
    get {
        return _globalCdn
    }
    set {
        _globalCdn = newValue
    }
}

var globalNetworkService: NewNetworkService {
    get {
        if _globalNetworkService == nil {
            fatalError("NewNetworkService 没有被初始化，请确保在应用启动时初始化")
        }
        return _globalNetworkService!
    }
    set {
        _globalNetworkService = newValue
    }
}

var globalNetworkManager: NetworkManager {
    get {
        if _globalNetworkManager == nil {
            fatalError("NetworkManager 没有被初始化，请确保在应用启动时初始化")
        }
        return _globalNetworkManager!
    }
    set {
        _globalNetworkManager = newValue
    }
}

var globalNewDownloadUtils: NewDownloadUtils {
    get {
        if _globalNewDownloadUtils == nil {
            fatalError("NewDownloadUtils 没有被初始化，请确保在应用启动时初始化")
        }
        return _globalNewDownloadUtils!
    }
    set {
        _globalNewDownloadUtils = newValue
    }
}

var globalCancelTracker: CancelTracker {
    get {
        if _globalCancelTracker == nil {
            _globalCancelTracker = CancelTracker()
        }
        return _globalCancelTracker!
    }
    set {
        _globalCancelTracker = newValue
    }
}

var globalProducts: [Product] {
    get {
        if _globalProducts == nil {
            _globalProducts = []
        }
        return _globalProducts!
    }
    set {
        _globalProducts = newValue
    }
}

var globalUniqueProducts: [UniqueProduct] {
    get {
        if _globalUniqueProducts == nil {
            _globalUniqueProducts = []
        }
        return _globalUniqueProducts!
    }
    set {
        _globalUniqueProducts = newValue
    }
}

func getAllProducts() -> [Product] {
    var allProducts = [Product]()
    let stiProducts = globalStiResult.products
    if !stiProducts.isEmpty {
        allProducts.append(contentsOf: stiProducts)
    }
    let ccmProducts = globalCcmResult.products
    if !ccmProducts.isEmpty {
        allProducts.append(contentsOf: ccmProducts)
    }
    return allProducts
}

/// 根据产品ID和版本号快速查找产品
/// - Parameters:
///   - id: 产品ID
///   - version: 版本号（可选）
/// - Returns: 如果提供版本号，返回指定版本的产品；否则返回最新版本的产品
func findProduct(id: String, version: String? = nil) -> Product? {
    // 首先在全局产品列表中查找匹配ID的产品
    guard let product = globalProducts.first(where: { $0.id == id }) else {
        return nil
    }
    
    // 如果没有指定版本，直接返回找到的产品
    guard let version = version else {
        return product
    }
    
    // 检查产品的平台和语言集是否包含指定版本
    for platform in product.platforms {
        for languageSet in platform.languageSet {
            if languageSet.productVersion == version {
                return product
            }
        }
    }
    
    return nil
}

/// 获取产品的所有可用版本
/// - Parameter id: 产品ID
/// - Returns: 版本号数组，已去重并按版本号排序
func getProductVersions(id: String) -> [String] {
    guard let product = globalProducts.first(where: { $0.id == id }) else {
        return []
    }
    
    // 收集所有平台和语言集中的版本号
    var versions = Set<String>()
    for platform in product.platforms {
        for languageSet in platform.languageSet {
            versions.insert(languageSet.productVersion)
        }
    }
    
    // 转换为数组并按版本号排序（降序）
    return Array(versions).sorted { version1, version2 in
        version1.compare(version2, options: .numeric) == .orderedDescending
    }
}

/// 获取产品在指定版本下的所有可用语言
/// - Parameters:
///   - id: 产品ID
///   - version: 版本号
/// - Returns: 语言代码数组
func getProductLanguages(id: String, version: String) -> [String] {
    guard let product = globalProducts.first(where: { $0.id == id }) else {
        return []
    }
    
    var languages = Set<String>()
    for platform in product.platforms {
        for languageSet in platform.languageSet {
            if languageSet.productVersion == version {
                languages.insert(languageSet.name)
            }
        }
    }
    
    return Array(languages).sorted()
}

/// 查找所有匹配指定ID的产品
/// - Parameter id: 产品ID
/// - Returns: 匹配的产品数组
func findProducts(id: String) -> [Product] {
    var matchedProducts = [Product]()
    
    // 从 globalProducts 中查找
    matchedProducts.append(contentsOf: globalProducts.filter { $0.id == id })
    
    // 从 globalCcmResult 中查找
    matchedProducts.append(contentsOf: globalCcmResult.products.filter { $0.id == id })
    
    // 从 globalStiResult 中查找
    matchedProducts.append(contentsOf: globalStiResult.products.filter { $0.id == id })
    
    return matchedProducts
}
