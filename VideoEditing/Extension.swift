//
//  Extension.swift
//  VideoEditing
//
//  Created by Plexus Technology on 26/02/25.
//

import Foundation
import AVFoundation


extension CMTime {
    var displayString: String {
        let offset = TimeInterval(seconds)
        let numberOfNanosecondsFloat = (offset - TimeInterval(Int(offset))) * 1000.0
        let nanoseconds = Int(numberOfNanosecondsFloat)
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        formatter.allowedUnits = [.minute, .second]
        return String(format: "%@.%03d", formatter.string(from: offset) ?? "00:00", nanoseconds)
    }
}

extension AVAsset {
    var fullRange: CMTimeRange {
        return CMTimeRange(start: .zero, duration: duration)
    }
    
    func trimmedComposition(_ range: CMTimeRange) -> AVAsset {
        guard CMTimeRangeEqual(fullRange, range) == false else { return self }
        
        let composition = AVMutableComposition()
        try? composition.insertTimeRange(range, of: self, at: .zero)
        
        if let videoTrack = tracks(withMediaType: .video).first {
            composition.tracks.forEach { $0.preferredTransform = videoTrack.preferredTransform }
        }
        return composition
    }
}

// MARK: - Associated Keys for object association
struct AssociatedKeys {
    static var stickerViewsKey = "VideoStickerVC.stickerViewsKey"
}

