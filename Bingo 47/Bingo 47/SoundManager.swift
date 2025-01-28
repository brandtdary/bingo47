//
//  SoundManager.swift
//  Bingo 47
//
//  Created by Brandt Dary on 12/21/24.
//

import UIKit
import AVFAudio

final class SoundManager {
    static let shared = SoundManager()
    private var soundPools: [Sound: [AVAudioPlayer]] = [:]

    private init() {
        configureAudioSession()
        NotificationCenter.default.addObserver(self, selector: #selector(restartAudioAfterAd), name: .rewardedAdDidFinish, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleAudioInterruption), name: AVAudioSession.interruptionNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appDidBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)

    }

    @objc private func handleAudioInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

        switch type {
        case .began:
            print("🔇 Audio session interrupted.")
        case .ended:
            configureAudioSession()
        @unknown default:
            break
        }
    }
    
    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            print("🎵 Audio session configured successfully.")
        } catch {
            let errorMessage = "❌ Failed to configure audio session: \(error.localizedDescription)"
            NotificationCenter.default.post(name: .errorNotification, object: nil, userInfo: ["message": errorMessage,"function": #function])
            print(errorMessage)
        }
    }
    
    @objc private func restartAudioAfterAd() {
        configureAudioSession()
    }
    
    @objc private func appDidBecomeActive() {
        configureAudioSession()
    }
    
    func playSound(_ sound: Sound) {
        // Ensure the sound file exists
        guard let url = Bundle.main.url(forResource: sound.fileName, withExtension: sound.fileExtension) else {
            let errorMessage = "❌ Sound file \(sound.fileName).\(sound.fileExtension) not found."
            print(errorMessage)
            NotificationCenter.default.post(name: .errorNotification, object: nil, userInfo: ["message": errorMessage,"function": #function])
            return
        }
        
        // Check for an available player
        if let pool = soundPools[sound] { // ✅ Changed 'var' to 'let'
            if let availablePlayer = pool.first(where: { !$0.isPlaying }) {
                availablePlayer.currentTime = 0  // Reset to start
                availablePlayer.play()
                return
            }
        } else {
            soundPools[sound] = [] // Initialize pool if not exists
        }
        
        // No available player, create a new one
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            player.play()
            
            soundPools[sound]?.append(player) // Add to the pool
        } catch {
            let errorMessage = "❌ Error playing sound \(sound.fileName): \(error.localizedDescription)"
            NotificationCenter.default.post(name: .errorNotification, object: nil, userInfo: ["message": errorMessage,"function": #function])
            print(errorMessage)
        }
    }

    
    deinit {
        let errorMessage = "❌ SoundManager is being deallocated unexpectedly!"
        NotificationCenter.default.post(name: .errorNotification, object: nil, userInfo: ["message": errorMessage,"function": #function])
        print(errorMessage)
    }
}

// Existing Sound Enum for Sound Effects
enum Sound: String, CaseIterable {
    case bingo, go, called, welcome, click, gameOver, adReward, purchasedChips, freeChips, lowerBet, first3, first3inOrder, beepUp, beepDown, markedNotCalled, markedCalled

    var fileName: String { rawValue }
    var fileExtension: String { "mp3" } // Change if needed
}



extension Notification.Name {
    static let errorNotification = Notification.Name("errorNotification")
    static let rewardedAdDidFinish = Notification.Name("rewardDidFinishNotification")
}
