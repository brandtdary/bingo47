//
//  HapticManager.swift
//  App by GudMilk
//
//  Created by Brandt Dary on 12/21/24.
//

import UIKit
import SwiftUI

final class HapticManager {
    static let shared = HapticManager()
    
    @AppStorage("vibrationEnabled") var vibrationEnabled: Bool = true

    private var feedbackPools: [HapticType: [UIImpactFeedbackGenerator]] = [:]

    enum HapticType {
        case light, medium, heavy, soft, rigid

        var feedbackStyle: UIImpactFeedbackGenerator.FeedbackStyle {
            switch self {
            case .light: return .light
            case .medium: return .medium
            case .heavy: return .heavy
            case .soft: return .soft
            case .rigid: return .rigid
            }
        }
    }
    
    enum HapticEvent {
        case wrongNumber
        case correctNumber
        case bingo
        case choose
        case soft
        case light
    }

    // Enforce singleton pattern by preventing external instantiation
    private init() {}

    // MARK: - Public API

    func triggerHaptic(for event: HapticEvent) {
        let hapticType = mapEventToHapticType(event)
        triggerHaptic(hapticType)
    }

    // MARK: - Private Mapping Layer

    private func mapEventToHapticType(_ event: HapticEvent) -> HapticType {
        switch event {
        case .wrongNumber:
            return .rigid
        case .correctNumber, .bingo, .choose:
            return .medium
        case .soft:
            return .soft
        case .light:
            return .light
        }
    }

    private func triggerHaptic(_ type: HapticType) {
        guard vibrationEnabled else { return }

        // If no pool exists for this type, create one dynamically
        if feedbackPools[type] == nil {
            feedbackPools[type] = []
        }

        // Get the pool for the type
        guard let pool = feedbackPools[type] else { return }

        // Try to find an available generator
        if let generator = pool.first(where: { !$0.isImpacting }) {
            generator.impactOccurred()
        } else {
            // If no generator is available, create one and add it to the pool
            let generator = UIImpactFeedbackGenerator(style: type.feedbackStyle)
            generator.prepare()
            generator.impactOccurred()
            feedbackPools[type]?.append(generator)
        }
    }
}

// MARK: - Extension for Dynamic Pool Handling
private extension UIImpactFeedbackGenerator {
    var isImpacting: Bool {
        // There's no direct API to check if a generator is "busy,"
        // but we assume it's not busy after `impactOccurred()`.
        // For now, this is a placeholder that always returns `false`.
        return false
    }
}
