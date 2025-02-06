//
//  Adobe Downloader
//
//  Created by X1a0He on 2024/10/30.
//
import Foundation
import AppKit

extension NewDownloadTask {
    var startTime: Date {
        switch totalStatus {
        case .downloading(let info): return info.startTime
        case .completed(let info): return info.timestamp - info.totalTime
        case .preparing(let info): return info.timestamp
        case .paused(let info): return info.timestamp
        case .failed(let info): return info.timestamp
        case .retrying(let info): return info.nextRetryDate - 60
        case .waiting, .none: return createAt
        }
    }
}
