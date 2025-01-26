//
//  SoundManager.swift
//  GudBingo
//
//  Created by Brandt Dary on 12/21/24.
//

import UIKit
import AVFoundation

final class SoundManager {
    static let shared = SoundManager()
    private var soundPools: [Sound: [AVAudioPlayer]] = [:]

    private init() {
        setupAudioSession()
        NotificationCenter.default.addObserver(self, selector: #selector(restartAudioAfterAd), name: .rewardedAdDidFinish, object: nil)
    }

    private func setupAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            print("✅ Audio session set up successfully.")
        } catch {
            NotificationCenter.default.post(name: .errorNotification, object: nil, userInfo: ["message": "❌ Failed to set up audio session: \(error.localizedDescription)","function": #function])
            print("❌ Failed to set up audio session: \(error.localizedDescription)")
        }
    }
    
    @objc private func restartAudioAfterAd() {
        print("🔄 Restarting audio session after ad...")
        restartAudioSession()
    }
    
    private func restartAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            NotificationCenter.default.post(name: .errorNotification, object: nil, userInfo: ["message": "❌ Failed to restart audio session: \(error.localizedDescription)","function": #function])
            print("❌ Failed to restart audio session: \(error.localizedDescription)")
        }
    }



    func playSound(_ sound: Sound) {
        // Ensure the sound file exists
        guard let url = Bundle.main.url(forResource: sound.fileName, withExtension: sound.fileExtension) else {
            print("❌ Sound file \(sound.fileName).\(sound.fileExtension) not found.")
            NotificationCenter.default.post(name: .errorNotification, object: nil, userInfo: ["message": "❌ Sound file \(sound.fileName).\(sound.fileExtension) not found.","function": #function])
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
            NotificationCenter.default.post(name: .errorNotification, object: nil, userInfo: ["message": "❌ Error playing sound \(sound.fileName): \(error.localizedDescription)","function": #function])
            print("❌ Error playing sound \(sound.fileName): \(error.localizedDescription)")
        }
    }

    
    deinit {
        NotificationCenter.default.post(name: .errorNotification, object: nil, userInfo: ["message": "❌ SoundManager is being deallocated unexpectedly!","function": #function])
        print("❌ SoundManager is being deallocated unexpectedly!")
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
