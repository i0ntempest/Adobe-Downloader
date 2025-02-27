//
//  Globals.swift
//  Adobe Downloader
//
//  Created by X1a0He on 2/26/25.
//

// 下面是所有全局变量的私有存储
private var _globalStiResult: NewParseResult?
private var _globalCcmResult: NewParseResult?
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
