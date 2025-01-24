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
    
    private var audioEngine = AVAudioEngine()
    private var playerNodes: [Sound: AVAudioPlayerNode] = [:]

    private var playerNodePools: [Sound: [AVAudioPlayerNode]] = [:]
    private let maxPlayerNodesPerSound = 5 // Adjust as needed
    private var audioBuffers: [Sound: AVAudioPCMBuffer] = [:]
    
//    private var soundPools: [Sound: [AVAudioPlayer]] = [:] // Dictionary to hold pools for each sound
//    private let poolSize = 1 // Default number of players per sound pool
    
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
        preloadAllSounds()
        registerForAppLifecycleNotifications()
    }

    private func setupAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers, .duckOthers])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            NotificationCenter.default.post(name: .soundError, object: nil, userInfo: ["message": "✅ Audio session set to .playback and activated successfully.","function": #function])
            print("✅ Audio session set to .playback and activated successfully.")
        } catch {
            NotificationCenter.default.post(name: .soundError, object: nil, userInfo: ["message": "❌ Failed to set up audio session: \(error.localizedDescription)","function": #function])
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
            var nodePool: [AVAudioPlayerNode] = []
            
            for _ in 0..<maxPlayerNodesPerSound { // ✅ Create multiple nodes for each sound
                let playerNode = AVAudioPlayerNode()
                audioEngine.attach(playerNode)
                nodePool.append(playerNode)
            }
            
            guard let url = Bundle.main.url(forResource: sound.fileName, withExtension: sound.fileExtension) else {
                NotificationCenter.default.post(name: .soundError, object: nil, userInfo: ["message": "❌ Sound file \(sound.fileName).\(sound.fileExtension) not found.","function": #function])

                print("❌ Sound file \(sound.fileName).\(sound.fileExtension) not found.")
                continue
            }

            do {
                let audioFile = try AVAudioFile(forReading: url)
                let format = audioFile.processingFormat
                let frameCount = AVAudioFrameCount(audioFile.length)
                let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
                try audioFile.read(into: buffer)

                // Connect all player nodes to the mixer
                for playerNode in nodePool {
                    audioEngine.connect(playerNode, to: audioEngine.mainMixerNode, format: format)
                }

                playerNodePools[sound] = nodePool
                audioBuffers[sound] = buffer
            } catch {
                NotificationCenter.default.post(name: .soundError, object: nil, userInfo: ["message": "❌ Error loading sound file \(sound.fileName): \(error.localizedDescription)","function": #function])

                print("❌ Error loading sound file \(sound.fileName): \(error.localizedDescription)")
            }
        }

        do {
            try audioEngine.start()
            print("✅ Audio engine started successfully.")
        } catch {
            NotificationCenter.default.post(name: .soundError, object: nil, userInfo: ["message": "❌ Failed to start audio engine: \(error.localizedDescription)","function": #function])
            print("❌ Failed to start audio engine: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Play Short Sound
    func playSound(_ sound: Sound) {
        guard let buffer = audioBuffers[sound], let nodePool = playerNodePools[sound] else {
            NotificationCenter.default.post(name: .soundError, object: nil, userInfo: ["message": "❌ Player node or buffer for sound \(sound) not found.","function": #function])
            print("❌ Player node or buffer for sound \(sound) not found.")
            return
        }

        // Get an available player node (rotate through them)
        let playerNode = nodePool.randomElement()! // ✅ Randomly pick a node for simultaneous play
        
        if playerNode.isPlaying {
            playerNode.stop() // Stop only if necessary (optional)
        }

        playerNode.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
        playerNode.play()
    }
}


extension Notification.Name {
    static let soundError = Notification.Name("soundError")
}
