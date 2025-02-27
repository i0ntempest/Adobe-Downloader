////
////  JSONParser.swift
////  Adobe Downloader
////
////  Created by X1a0He on 11/18/24.
////
//
//import Foundation
//
// struct ParseResult {
//     var products: [String: Sap]
//     var cdn: String
// }
//
//class JSONParser {
//    static func parse(jsonString: String) throws -> ParseResult {
//        guard let jsonData = jsonString.data(using: .utf8),
//              let jsonObject = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
//            throw ParserError.invalidJSON
//        }
//        let apiVersion = Int(StorageData.shared.apiVersion) ?? 6
//        
//        return try parseProductsJSON(jsonObject: jsonObject, apiVersion: apiVersion)
//    }
//    
//    private static func parseProductsJSON(jsonObject: [String: Any], apiVersion: Int) throws -> ParseResult {
//        let cdnPath: [String]
//        if apiVersion == 6 {
//            cdnPath = ["channels", "channel"]
//        } else {
//            cdnPath = ["channel"]
//        }
//
//        func getValue(from dict: [String: Any], path: [String]) -> Any? {
//            var current: Any = dict
//            for key in path {
//                guard let dict = current as? [String: Any],
//                      let value = dict[key] else {
//                    return nil
//                }
//                current = value
//            }
//            return current
//        }
//
//        var channelArray: [[String: Any]] = []
//        if let channels = getValue(from: jsonObject, path: cdnPath) {
//            if let array = channels as? [[String: Any]] {
//                channelArray = array
//            } else if let dict = channels as? [String: Any],
//                      let array = dict["channel"] as? [[String: Any]] {
//                channelArray = array
//            }
//        }
//
//        guard let firstChannel = channelArray.first,
//              let cdn = (firstChannel["cdn"] as? [String: Any])?["secure"] as? String else {
//            throw ParserError.missingCDN
//        }
//
//        var products = [String: Sap](minimumCapacity: 200)
//
//        for channel in channelArray {
//            let channelName = channel["name"] as? String
//            let hidden = channelName != "ccm"
//            
//            guard let productsContainer = channel["products"] as? [String: Any],
//                  let productArray = productsContainer["product"] as? [[String: Any]] else {
//                continue
//            }
//
//            for product in productArray {
//                guard let sap = product["id"] as? String,
//                      let displayName = product["displayName"] as? String,
//                      let productVersion = product["version"] as? String else {
//                    continue
//                }
//
//                if products[sap] == nil {
//                    let icons = (product["productIcons"] as? [String: Any])?["icon"] as? [[String: Any]] ?? []
//                    let productIcons = icons.compactMap { icon -> Sap.ProductIcon? in
//                        guard let size = icon["size"] as? String,
//                              let value = icon["value"] as? String else {
//                            return nil
//                        }
//                        return Sap.ProductIcon(size: size, url: value)
//                    }
//                    
//                    products[sap] = Sap(
//                        hidden: hidden,
//                        displayName: displayName,
//                        sapCode: sap,
//                        versions: [:],
//                        icons: productIcons
//                    )
//                }
//
//                if let platforms = product["platforms"] as? [String: Any],
//                   let platformArray = platforms["platform"] as? [[String: Any]] {
//                    
//                    for platform in platformArray {
//                        guard let platformId = platform["id"] as? String,
//                              let languageSets = platform["languageSet"] as? [[String: Any]],
//                              let languageSet = languageSets.first else {
//                            continue
//                        }
//
//                        if let existingVersion = products[sap]?.versions[productVersion],
//                           StorageData.shared.allowedPlatform.contains(existingVersion.apPlatform) {
//                            break
//                        }
//                        
//                        var baseVersion = languageSet["baseVersion"] as? String ?? ""
//                        var buildGuid = languageSet["buildGuid"] as? String ?? ""
//                        var finalProductVersion = productVersion
//
//                        if sap == "APRO" {
//                            baseVersion = productVersion
//                            if apiVersion == 4 || apiVersion == 5 {
//                                if let appVersion = (languageSet["nglLicensingInfo"] as? [String: Any])?["appVersion"] as? String {
//                                    finalProductVersion = appVersion
//                                }
//                            } else if apiVersion == 6 {
//                                if let builds = jsonObject["builds"] as? [String: Any],
//                                   let buildArray = builds["build"] as? [[String: Any]] {
//                                    for build in buildArray {
//                                        if build["id"] as? String == sap && build["version"] as? String == baseVersion,
//                                           let appVersion = (build["nglLicensingInfo"] as? [String: Any])?["appVersion"] as? String {
//                                            finalProductVersion = appVersion
//                                            break
//                                        }
//                                    }
//                                }
//                            }
//                            
//                            if let urls = languageSet["urls"] as? [String: Any],
//                               let manifestURL = urls["manifestURL"] as? String {
//                                buildGuid = manifestURL
//                            }
//                        }
//
//                        var dependencies: [Sap.Versions.Dependencies] = []
//                        if let deps = languageSet["dependencies"] as? [String: Any],
//                           let depArray = deps["dependency"] as? [[String: Any]] {
//                            dependencies = depArray.compactMap { dep in
//                                guard let sapCode = dep["sapCode"] as? String,
//                                      let version = dep["baseVersion"] as? String else {
//                                    return nil
//                                }
//                                return Sap.Versions.Dependencies(sapCode: sapCode, version: version)
//                            }
//                        }
//                        
//                        if !buildGuid.isEmpty {
//                            let version = Sap.Versions(
//                                sapCode: sap,
//                                baseVersion: baseVersion,
//                                productVersion: finalProductVersion,
//                                apPlatform: platformId,
//                                dependencies: dependencies,
//                                buildGuid: buildGuid
//                            )
//                            products[sap]?.versions[finalProductVersion] = version
//                        }
//                    }
//                }
//            }
//        }
//        
//        return ParseResult(products: products, cdn: cdn)
//    }
//}
