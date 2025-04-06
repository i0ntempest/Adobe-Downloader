//
//  NewJSONParser.swift
//  Adobe Downloader
//
//  Created by X1a0He on 2/26/25.
//

import Foundation

/**
    v6: https://prod-rel-ffc-ccm.oobesaas.adobe.com/adobe-ffc-external/core/v6/products/all?channel=ccm&channel=sti&platform=macarm64,macuniversal,osx10-64,osx10&_type=json&productType=Desktop
    v5: https://prod-rel-ffc-ccm.oobesaas.adobe.com/adobe-ffc-external/core/v5/products/all?channel=ccm&channel=sti&platform=macarm64,macuniversal,osx10-64,osx10&_type=json&productType=Desktop
    v4: https://prod-rel-ffc-ccm.oobesaas.adobe.com/adobe-ffc-external/core/v4/products/all?channel=ccm&channel=sti&platform=macarm64,macuniversal,osx10-64,osx10&_type=json&productType=Desktop
*/

class NewJSONParser {
    static func parse(jsonString: String) throws {
        guard let jsonData = jsonString.data(using: .utf8),
              let jsonObject = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            throw ParserError.invalidJSON
        }
        let apiVersion = Int(StorageData.shared.apiVersion) ?? 6
        globalStiResult = try parseSti(jsonObject: jsonObject, apiVersion: apiVersion)
        globalCcmResult = try parseCcm(jsonObject: jsonObject, apiVersion: apiVersion)
        
        // 更新全局 CDN
        if !globalCcmResult.cdn.isEmpty {
            globalCdn = globalCcmResult.cdn
        } else if !globalStiResult.cdn.isEmpty {
            globalCdn = globalStiResult.cdn
        }
    }

    static func parseStiProducts(jsonString: String) throws {
        guard let jsonData = jsonString.data(using: .utf8),
              let jsonObject = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            throw ParserError.invalidJSON
        }
        let apiVersion = Int(StorageData.shared.apiVersion) ?? 6
        let result = try parseSti(jsonObject: jsonObject, apiVersion: apiVersion)
        globalStiResult = result
        
        // 更新全局 CDN
        globalCdn = result.cdn
    }

    static func parseCcmProducts(jsonString: String) throws {
        guard let jsonData = jsonString.data(using: .utf8),
              let jsonObject = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            throw ParserError.invalidJSON
        }
        let apiVersion = Int(StorageData.shared.apiVersion) ?? 6
        let result = try parseCcm(jsonObject: jsonObject, apiVersion: apiVersion)
        globalCcmResult = result
        
        // 更新全局 CDN
        globalCdn = result.cdn
    }

    private static func parseSti(jsonObject: [String: Any], apiVersion: Int) throws -> NewParseResult {
        let cdnPath: [String]
        if apiVersion == 6 {
            cdnPath = ["channels", "channel"]
        } else {
            cdnPath = ["channel"]
        }

        func getValue(from dict: [String: Any], path: [String]) -> Any? {
            var current: Any = dict
            for key in path {
                guard let dict = current as? [String: Any],
                      let value = dict[key] else {
                    return nil
                }
                current = value
            }
            return current
        }

        var channelArray: [[String: Any]] = []
        if let channels = getValue(from: jsonObject, path: cdnPath) {
            if let array = channels as? [[String: Any]] {
                channelArray = array
            } else if let dict = channels as? [String: Any],
                      let array = dict["channel"] as? [[String: Any]] {
                channelArray = array
            }
        }

        guard let firstChannel = channelArray.first,
              let cdn = (firstChannel["cdn"] as? [String: Any])?["secure"] as? String else {
            throw ParserError.missingCDN
        }

        var products = [Product]()

        for channel in channelArray {
            let channelName = channel["name"] as? String ?? ""
            if(channelName != "sti") { continue }

            guard let productsContainer = channel["products"] as? [String: Any],
                  let productArray = productsContainer["product"] as? [[String: Any]] else {
                continue
            }

            for product in productArray {

                guard let productId = product["id"] as? String,
                      let productDisplayName = product["displayName"] as? String,
                      let productVersion = product["version"] as? String else {
                    continue
                }

                /**
                 sti 的 referencedProducts 就是空的，不需要
                 同时也不需要 icon，因为是隐藏的，所以这个不要也罢
                 */
                var productObject = Product(
                    type: product["type"] as? String ?? "",
                    displayName: productDisplayName,
                    family: product["family"] as? String ?? "",
                    appLineage: product["appLineage"] as? String ?? "",
                    familyName: product["familyName"] as? String ?? "",
                    productIcons: [],
                    platforms: [],
                    referencedProducts: [],
                    version: productVersion,
                    id: productId,
                    hidden: true
                )

                if let platforms = product["platforms"] as? [String: Any],
                   let platformArray = platforms["platform"] as? [[String: Any]] {
                    for platform in platformArray {
                        guard let platformId = platform["id"] as? String,
                              let languageSets = platform["languageSet"] as? [[String: Any]],
                              let languageSet = languageSets.first else {
                            continue
                        }

                        // sti 的 dependencies 就是空的
                        let newLanguageSet = Product.Platform.LanguageSet(
                            manifestURL: (languageSet["urls"] as? [String: Any])?["manifestURL"] as? String ?? "",
                            dependencies: [],
                            productCode: languageSet["productCode"] as? String ?? "",
                            name: languageSet["name"] as? String ?? "",
                            installSize: languageSet["installSize"] as? Int ?? 0,
                            buildGuid: languageSet["buildGuid"] as? String ?? "", // 将 buildGuid 赋值给 LanguageSet
                            baseVersion: languageSet["baseVersion"] as? String ?? "",
                            productVersion: languageSet["productVersion"] as? String ?? ""
                        )

                        // sti 的 module 也是空的，不需要
                        var newPlatform = Product.Platform(
                            languageSet: [newLanguageSet],
                            modules: [],
                            range: [],
                            id: platformId
                        )

                        if let range = platform["systemCompatibility"] as? [String: Any],
                           let operatingSystem = range["operatingSystem"] as? [String: Any],
                           let rangeArray = operatingSystem["range"] as? [String] {
                            let min = rangeArray.first ?? ""
                            let max = rangeArray.count > 1 ? rangeArray[1] : ""
                            let newRange = Product.Platform.Range(min: min, max: max)
                            newPlatform.range = [newRange]
                        }

                        productObject.platforms.append(newPlatform)
                    }
                }
                products.append(productObject)
                
            }
        }

        return NewParseResult(products: products, cdn: cdn)
    }

    private static func parseCcm(jsonObject: [String: Any], apiVersion: Int) throws -> NewParseResult {
        let cdnPath: [String]
        if apiVersion == 6 {
            cdnPath = ["channels", "channel"]
        } else {
            cdnPath = ["channel"]
        }

        func getValue(from dict: [String: Any], path: [String]) -> Any? {
            var current: Any = dict
            for key in path {
                guard let dict = current as? [String: Any],
                      let value = dict[key] else {
                    return nil
                }
                current = value
            }
            return current
        }

        var channelArray: [[String: Any]] = []
        if let channels = getValue(from: jsonObject, path: cdnPath) {
            if let array = channels as? [[String: Any]] {
                channelArray = array
            } else if let dict = channels as? [String: Any],
                      let array = dict["channel"] as? [[String: Any]] {
                channelArray = array
            }
        }

        guard let firstChannel = channelArray.first,
              let cdn = (firstChannel["cdn"] as? [String: Any])?["secure"] as? String else {
            throw ParserError.missingCDN
        }

        var products = [Product]()

        for channel in channelArray {
            let channelName = channel["name"] as? String ?? ""
            if(channelName != "ccm") { continue }

            guard let productsContainer = channel["products"] as? [String: Any],
                  let productArray = productsContainer["product"] as? [[String: Any]] else {
                continue
            }

            for product in productArray {
                guard let productId = product["id"] as? String,
                      let productDisplayName = product["displayName"] as? String,
                      let productVersion = product["version"] as? String else {
                    continue
                }

                if productDisplayName == "Creative Cloud" { continue }

                let icons = (product["productIcons"] as? [String: Any])?["icon"] as? [[String: Any]] ?? []
                let productIcons = icons.compactMap { icon -> Product.ProductIcon? in
                    guard let size = icon["size"] as? String,
                          let value = icon["value"] as? String else {
                        return nil
                    }
                    return Product.ProductIcon(value: value, size: size)
                }

                var productObject = Product(
                    type: product["type"] as? String ?? "",
                    displayName: productDisplayName,
                    family: product["family"] as? String ?? "",
                    appLineage: product["appLineage"] as? String ?? "",
                    familyName: product["familyName"] as? String ?? "",
                    productIcons: productIcons,
                    platforms: [],
                    referencedProducts: [],
                    version: productVersion,
                    id: productId,
                    hidden: false
                )

                if let platforms = product["platforms"] as? [String: Any],
                   let platformArray = platforms["platform"] as? [[String: Any]] {
                    for platform in platformArray {
                        guard let platformId = platform["id"] as? String,
                              let languageSets = platform["languageSet"] as? [[String: Any]],
                              let languageSet = languageSets.first else {
                            continue
                        }

                        var newLanguageSet = Product.Platform.LanguageSet(
                            manifestURL: (languageSet["urls"] as? [String: Any])?["manifestURL"] as? String ?? "",
                            dependencies: [],
                            productCode: languageSet["productCode"] as? String ?? "",
                            name: languageSet["name"] as? String ?? "",
                            installSize: languageSet["installSize"] as? Int ?? 0,
                            buildGuid: languageSet["buildGuid"] as? String ?? "",
                            baseVersion: languageSet["baseVersion"] as? String ?? "",
                            productVersion: languageSet["productVersion"] as? String ?? ""
                        )

                        var dependencies: [Product.Platform.LanguageSet.Dependency] = []
                        if let deps = languageSet["dependencies"] as? [String: Any],
                           let depArray = deps["dependency"] as? [[String: Any]] {
                            dependencies = depArray.compactMap { dep in
                                guard let sapCode = dep["sapCode"] as? String,
                                      let baseVersion = dep["baseVersion"] as? String else {
                                    return Product.Platform.LanguageSet.Dependency(sapCode: "",baseVersion: "",productVersion: "",buildGuid: "")
                                }
                                let targetPlatform = StorageData.shared.downloadAppleSilicon ? "macarm64" : "osx10-64"
                                let cacheKey = DependencyCacheKey(sapCode: sapCode, targetPlatform: targetPlatform)

                                if let cachedDependency = globalDependencyCache[cacheKey] {
                                    return cachedDependency
                                }

                                var productVersion = ""
                                var buildGuid = ""
                                var isMatchPlatform = false
                                var selectedPlatform = ""
                                var selectedReason = ""
                                
                                if !globalStiResult.products.isEmpty {
                                    let matchingProducts = globalStiResult.products.filter { $0.id == sapCode }
                                    
                                    if let latestProduct = matchingProducts.sorted(by: {
                                        return AppStatics.compareVersions($0.version, $1.version) > 0
                                    }).first {
                                        if let matchingPlatform = latestProduct.platforms.first(where: { platform in
                                            platform.id == targetPlatform || platform.id == "macuniversal"
                                        }),
                                           let firstLanguageSet = matchingPlatform.languageSet.first {
                                            productVersion = firstLanguageSet.productVersion
                                            buildGuid = firstLanguageSet.buildGuid
                                            isMatchPlatform = true
                                            selectedPlatform = matchingPlatform.id
                                            selectedReason = matchingPlatform.id == "macuniversal" ? 
                                                "成功匹配通用平台 macuniversal（支持所有 Mac 平台）" : 
                                                "成功匹配目标平台"
                                        } else {
                                            if let firstAvailablePlatform = latestProduct.platforms.first,
                                               let firstLanguageSet = firstAvailablePlatform.languageSet.first {
                                                productVersion = firstLanguageSet.productVersion
                                                buildGuid = firstLanguageSet.buildGuid
                                                isMatchPlatform = false
                                                selectedPlatform = firstAvailablePlatform.id
                                                selectedReason = "当前依赖所有版本中无匹配平台，使用可用平台: \(firstAvailablePlatform.id)"
                                            } else {
                                                selectedReason = "未找到任何可用平台"
                                            }
                                        }
                                    } else {
                                        selectedReason = "未找到最新版本产品"
                                    }
                                } else {
                                    selectedReason = "globalStiResult.products 为空"
                                }
                                
                                let dependency = Product.Platform.LanguageSet.Dependency(
                                    sapCode: sapCode, 
                                    baseVersion: baseVersion, 
                                    productVersion: productVersion,
                                    buildGuid: buildGuid,
                                    isMatchPlatform: isMatchPlatform,
                                    targetPlatform: targetPlatform,
                                    selectedPlatform: selectedPlatform,
                                    selectedReason: selectedReason
                                )

                                globalDependencyCache[cacheKey] = dependency
                                
                                return dependency
                            }
                            newLanguageSet.dependencies.append(contentsOf: dependencies)
                        }

                        var newPlatform = Product.Platform(
                            languageSet: [newLanguageSet],
                            modules: [],
                            range: [],
                            id: platformId
                        )

                        if let modules = platform["modules"] as? [String: Any],
                           let moduleArray = modules["module"] as? [[String: Any]] {
                            let newModules: [Product.Platform.Module] = moduleArray.compactMap { (module: [String: Any]) -> Product.Platform.Module? in
                                guard let displayName = module["displayName"] as? String,
                                      let deploymentType = module["deploymentType"] as? String,
                                      let id = module["id"] as? String else {
                                    return nil
                                }
                                return Product.Platform.Module(displayName: displayName, deploymentType: deploymentType, id: id)
                            }
                            newPlatform.modules = newModules
                        }

                        if let range = platform["systemCompatibility"] as? [String: Any],
                           let operatingSystem = range["operatingSystem"] as? [String: Any],
                           let rangeArray = operatingSystem["range"] as? [String] {
                            let min = rangeArray.first ?? ""
                            let max = rangeArray.count > 1 ? rangeArray[1] : ""
                            let newRange = Product.Platform.Range(min: min, max: max)
                            newPlatform.range = [newRange]
                        }

                        productObject.platforms.append(newPlatform)
                    }
                }

                if let referencedProductsArray = product["referencedProducts"] as? [[String: Any]] {
                    let referencedProducts: [Product.ReferencedProduct] = referencedProductsArray.compactMap { (refProduct: [String: Any]) -> Product.ReferencedProduct? in
                        guard let sapCode = refProduct["sapCode"] as? String,
                              let version = refProduct["version"] as? String else {
                            return nil
                        }
                        return Product.ReferencedProduct(sapCode: sapCode, version: version)
                    }
                    productObject.referencedProducts = referencedProducts
                }
                products.append(productObject)
            }
        }

        return NewParseResult(products: products, cdn: cdn)
    }
}
