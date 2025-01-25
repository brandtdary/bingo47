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
    private var activePlayers: [AVAudioPlayer] = [] // Keeps sounds from stopping early

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
            NotificationCenter.default.post(name: .errorNotification, object: nil, userInfo: ["message": "✅ Audio session restarted successfully.","function": #function])
            print("✅ Audio session restarted successfully.")
        } catch {
            NotificationCenter.default.post(name: .errorNotification, object: nil, userInfo: ["message": "❌ Failed to restart audio session: \(error.localizedDescription)","function": #function])
            print("❌ Failed to restart audio session: \(error.localizedDescription)")
        }
    }



    func playSound(_ sound: Sound) {
        guard let url = Bundle.main.url(forResource: sound.fileName, withExtension: sound.fileExtension) else {
            print("❌ Sound file \(sound.fileName).\(sound.fileExtension) not found.")
            NotificationCenter.default.post(name: .errorNotification, object: nil, userInfo: ["message": "❌ Sound file \(sound.fileName).\(sound.fileExtension) not found.","function": #function])
            return
        }

        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            player.play()

            activePlayers.append(player) // ✅ Store reference so sound doesn't stop early
            DispatchQueue.main.asyncAfter(deadline: .now() + player.duration) {
                self.activePlayers.removeAll { $0 == player } // ✅ Remove when done
            }
        } catch {
            NotificationCenter.default.post(name: .errorNotification, object: nil, userInfo: ["message": "❌ Error playing sound \(sound.fileName): \(error.localizedDescription)","function": #function])
            print("❌ Error playing sound \(sound.fileName): \(error.localizedDescription)")
        }
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
