//
//  Adobe Downloader
//
//  Created by X1a0He on 2024/10/30.
//
import Foundation
import SwiftUI
import AppKit


struct AppStatics {
    static let supportedLanguages: [(code: String, name: String)] = [
        ("en_US", "English (US)"),
        ("fr_FR", "Français"),
        ("de_DE", "Deutsch"),
        ("ja_JP", "日本語"),
        ("fr_CA", "Français (Canada)"),
        ("en_GB", "English (UK)"),
        ("nl_NL", "Nederlands"),
        ("it_IT", "Italiano"),
        ("es_ES", "Español"),
        ("ex_MX", "Español (Mexico)"),
        ("pt_BR", "Português (Brasil)"),
        ("pt_PT", "Português"),
        ("sv_SE", "Svenska"),
        ("da_DK", "Dansk"),
        ("fi_FI", "Suomi"),
        ("nb_NO", "Norsk"),
        ("zh_CN", "简体中文"),
        ("zh_TW", "繁體中文"),
        ("kr_KR", "한국어"),
        ("cs_CZ", "Čeština"),
        ("ht_HU", "Magyar"),
        ("pl_PL", "Polski"),
        ("ru_RU", "Русский"),
        ("uk_UA", "Українська"),
        ("tr_TR", "Türkçe"),
        ("ro_RO", "Romaân"),
        ("fr_MA", "Français (Maroc)"),
        ("en_AE", "English (UAE)"),
        ("en_IL", "English (Israel)"),
        ("ALL", "ALL")
    ]
    
    static let cpuArchitecture: String = {
        #if arch(arm64)
            return "Apple Silicon"
        #elseif arch(x86_64)
            return "Intel"
        #else
            return "Unknown Architecture"
        #endif
    }()
    
    static let isAppleSilicon: Bool = {
        #if arch(arm64)
            return true
        #elseif arch(x86_64)
            return false
        #else
            return false
        #endif
    }()

    static let architectureSymbol: String = {
        #if arch(arm64)
            return "arm64"
        #elseif arch(x86_64)
            return "x64"
        #else
            return "Unknown Architecture"
        #endif
    }()
    
    /// 比较两个版本号
    /// - Parameters:
    ///   - version1: 第一个版本号
    ///   - version2: 第二个版本号
    /// - Returns: 负值表示version1<version2，0表示相等，正值表示version1>version2
    static func compareVersions(_ version1: String, _ version2: String) -> Int {
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
}
