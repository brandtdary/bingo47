//
//  AppTrackingHelper.swift
//  GudBingo
//
//  Created by Brandt Dary on 1/3/25.
//


import AppTrackingTransparency
import AdSupport

class AppTrackingHelper {
    static func requestTrackingAuthorization() async -> Bool {
        if #available(iOS 14, *) {
            let status = await withCheckedContinuation { continuation in
                ATTrackingManager.requestTrackingAuthorization { status in
                    continuation.resume(returning: status)
                }
            }
            switch status {
            case .authorized:
                return true
            case .denied, .restricted, .notDetermined:
                return false
            @unknown default:
                return false
            }
        } else {
            // Fallback for earlier iOS versions
            return true
        }
    }
}
