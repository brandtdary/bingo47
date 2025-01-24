//
//  SoundManager.swift
//  GudBingo
//
//  Created by Brandt Dary on 12/21/24.
//

import AVFoundation
import UIKit

final class SoundManager {
    static let shared = SoundManager()
    
    private var soundPools: [Sound: [AVAudioPlayer]] = [:] // Dictionary to hold pools for each sound
    private let poolSize = 1 // Default number of players per sound pool
    
    // Existing Sound Enum for Sound Effects
    enum Sound: CaseIterable {
        case bingo
        case go
        case gameOver
        case called
        case welcome
        case click
        case markedNotCalled
        case markedCalled
        case adReward
        case purchasedChips
        case freeChips
        case lowerBet
        case first3
        case first3inOrder
        case beepUp
        case beepDown

        var fileName: String {
            switch self {
            case .bingo: return "bingo"
            case .go: return "go"
            case .called: return "called"
            case .welcome: return "welcome"
            case .click: return "click"
            case .markedNotCalled: return "markedNotCalled"
            case .gameOver: return "gameOver"
            case .markedCalled: return "SuperCoin2"
            case .adReward: return "adReward"
            case .purchasedChips: return "purchasedChips"
            case .freeChips: return "freeChips"
            case .lowerBet: return "lowerBet"
            case .first3: return "first3"
            case .first3inOrder: return "first3inOrder"
            case .beepUp: return "beepUp"
            case .beepDown: return "beepDown"
            }
        }
        
        var fileExtension: String {
            return "mp3" // Ensure your new sound files are in this format; update if needed
        }
    }
    
    private init() {
        setupAudioSession()
//        preloadAllSounds()
        registerForAppLifecycleNotifications()
    }
    
    private func setupAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers, .duckOthers]) // 🔹 Changed from .ambient to .playback
            try session.setActive(true, options: .notifyOthersOnDeactivation) // 🔹 Ensures it stays active
            print("✅ Audio session set to .playback and activated successfully.")
        } catch {
            NotificationCenter.default.post(
                name: .soundError,
                object: nil,
                userInfo: ["message": "Failed to set up audio session: \(error.localizedDescription)", "function": #function]
            )
            print("❌ Failed to set up audio session: \(error.localizedDescription)")
        }
    }
    
    private func restartAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(true)
            NotificationCenter.default.post(name: .soundError, object: nil, userInfo: ["message": "✅ Audio session restarted successfully.","function": #function])
            print("✅ Audio session restarted successfully.")
        } catch {
            NotificationCenter.default.post(name: .soundError, object: nil, userInfo: ["message": "❌ Failed to restart audio session: \(error.localizedDescription)","function": #function])

            print("❌ Failed to restart audio session: \(error.localizedDescription)")
        }
    }
    
    private func registerForAppLifecycleNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(appDidBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleAudioInterruption), name: AVAudioSession.interruptionNotification, object: nil)
    }
    
    @objc private func appDidBecomeActive() {
        restartAudioSession()
    }
    
    @objc private func handleAudioInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeRaw = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeRaw) else { return }

        switch type {
        case .began:
            print("🔹 Audio session interrupted.")
        case .ended:
            restartAudioSession()
        default:
            break
        }
    }

        
    // MARK: - Preload Short Sounds
    private func preloadAllSounds() {
        for sound in Sound.allCases {
            let customPoolSize: Int
            switch sound {
            case .markedCalled:
                customPoolSize = 5
            case .called:
                customPoolSize = 10
            case .beepUp, .beepDown:
                customPoolSize = 3
            default:
                customPoolSize = poolSize
            }
            preloadSound(sound, poolSize: customPoolSize)
            
            // Reduce volume for beepUp and beepDown
            if sound == .beepUp || sound == .beepDown || sound == .markedNotCalled {
                setVolume(for: sound, volume: 0.5) // Set to half volume, adjust as needed
            } else if sound == .bingo {
                setVolume(for: sound, volume: 0.25)
            } else {
                setVolume(for: sound, volume: 1.0)
            }
        }
    }

    private func preloadSound(_ sound: Sound, poolSize: Int) {
        guard let url = Bundle.main.url(forResource: sound.fileName, withExtension: sound.fileExtension) else {
#if DEBUG
            print("Sound file \(sound.fileName).\(sound.fileExtension) not found.")
#endif
            return
        }
        
        var pool: [AVAudioPlayer] = []
        do {
            for _ in 0..<poolSize {
                let player = try AVAudioPlayer(contentsOf: url)
                player.prepareToPlay()
                pool.append(player)
            }
            soundPools[sound] = pool
        } catch {
#if DEBUG
            NotificationCenter.default.post(name: .soundError, object: nil, userInfo: ["message": "Error preloading sound \(sound.fileName): \(error.localizedDescription)","function": #function])

            print("Error preloading sound \(sound.fileName): \(error.localizedDescription)")
#endif
        }
    }
    
    func setVolume(for sound: Sound, volume: Float) {
        guard let pool = soundPools[sound] else {
#if DEBUG
            NotificationCenter.default.post(name: .soundError, object: nil, userInfo: ["message": "No pool found for sound: \(sound)",
                                                                                       "function": #function])
            print("No pool found for sound: \(sound)")
#endif
            return
        }
        
        // Adjust the volume of each player in the pool
        for player in pool {
            player.volume = volume
        }
    }
    
    // MARK: - Play Short Sound
    func playSound(_ sound:  Sound) {
        // If there's no pool or it's empty, create it now
        if soundPools[sound] == nil || soundPools[sound]!.isEmpty {
            preloadSound(sound, poolSize: decidePoolSize(for: sound))
        }
        
        // Now grab the pool (it should exist after preloadSound, but just in case)
        guard let pool = soundPools[sound] else {
    #if DEBUG
            print("No pool found for sound: \(sound)")
            NotificationCenter.default.post(name: .soundError, object: nil, userInfo: ["message": "No pool found for sound: \(sound)",
                                                                                       "function": #function])

    #endif
            return
        }
        
        // Try to reuse an idle player
        if let player = pool.first(where: { !$0.isPlaying }) {
            player.currentTime = 0
            player.play()
        } else {
            // Optional: Dynamically create a new player if we haven't hit max pool size
            let maxPoolSize = 10 // Adjust as needed
            if pool.count < maxPoolSize {
                guard let url = Bundle.main.url(forResource: sound.fileName, withExtension: sound.fileExtension) else {
    #if DEBUG
                    print("Sound file \(sound.fileName).\(sound.fileExtension) not found.")
                    NotificationCenter.default.post(name: .soundError, object: nil, userInfo: ["message": "Sound \(sound) not found in pool",
                                                                                               "function": #function])
    #endif
                    return
                }
                do {
                    let newPlayer = try AVAudioPlayer(contentsOf: url)
                    newPlayer.prepareToPlay()
                    newPlayer.play()
                    soundPools[sound]?.append(newPlayer)
                } catch {
    #if DEBUG
                    NotificationCenter.default.post(name: .soundError, object: nil, userInfo: ["message": "Error creating new player for sound \(sound): \(error.localizedDescription)", "function": #function])

                    print("Error creating new player for sound \(sound): \(error.localizedDescription)")
    #endif
                }
            } else {
    #if DEBUG
                NotificationCenter.default.post(name: .soundError, object: nil, userInfo: ["message": "Maximum pool size reached for sound: \(sound)",
                                                                                           "function": #function])

                print("Maximum pool size reached for sound: \(sound)")
    #endif
            }
        }
    }
    
    private func decidePoolSize(for sound: Sound) -> Int {
        switch sound {
        case .markedCalled:
            return 5
        case .called:
            return 10
        case .beepUp, .beepDown:
            return 3
        default:
            return poolSize // This is your default pool size from the SoundManager
        }
    }
}


extension Notification.Name {
    static let soundError = Notification.Name("soundError")
}
