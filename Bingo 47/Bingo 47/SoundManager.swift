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

    
    // New BackgroundMusic Enum
    enum BackgroundMusic: String, CaseIterable {
        case firstThreeBonus = "firstThreeBonusMusic"
        // Add more background music cases here as needed

        var fileExtension: String {
            return "mp3" // Update if you have different file extensions
        }
    }
    
    // MARK: - Background Music
    private var backgroundMusicPlayer: AVAudioPlayer?
    private var isBackgroundMusicPlaying: Bool = false
    private var currentBackgroundMusic: BackgroundMusic?
    
    private init() {
        setupAudioSession()
        preloadAllSounds()
        registerForNotifications()
        registerForAppLifecycleNotifications()
    }
    
    private func setupAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
#if DEBUG
            print("Current Audio Session Category: \(session.category.rawValue)")
            print("Current Audio Session Mode: \(session.mode.rawValue)")
            print("Current Audio Session Options: \(session.categoryOptions)")
#endif
            
            try session.setCategory(.soloAmbient)
            try session.setActive(true)
#if DEBUG
            print("Audio session set to .ambient and activated successfully.")
#endif
        } catch {
            #if DEBUG
            print("Failed to set up audio session: \(error.localizedDescription)")
            #endif
        }
    }
    
    private func registerForNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleInterruption(_:)), name: AVAudioSession.interruptionNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleRouteChange(_:)), name: AVAudioSession.routeChangeNotification, object: nil)
    }
    
    @objc private func handleInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            // Audio session was interrupted, pause background music
            pauseBackgroundMusic()
            
        case .ended:
            // Audio session interruption ended, try to reactivate and resume music if needed
            do {
                try AVAudioSession.sharedInstance().setActive(true)
                if isBackgroundMusicPlaying {
                    resumeBackgroundMusic()
                }
            } catch {
#if DEBUG
                print("Error reactivating audio session: \(error.localizedDescription)")
#endif
            }
        @unknown default:
            break
        }
    }
    
    @objc private func handleRouteChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }

        switch reason {
        case .oldDeviceUnavailable:
            stopBackgroundMusic()
            try? AVAudioSession.sharedInstance().setActive(true)
            resumeBackgroundMusic()
            
        case .newDeviceAvailable:
            break
        default:
            break
        }
    }
    
    private func stopAllSounds() {
        for (_, players) in soundPools {
            players.forEach { $0.stop() }
        }
        stopBackgroundMusic()
    }
    
    private func registerForAppLifecycleNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(appDidBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appDidEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
    }
    
    @objc private func appDidBecomeActive() {
        try? AVAudioSession.sharedInstance().setActive(true)
        refreshSoundPlayers()
        if isBackgroundMusicPlaying {
            resumeBackgroundMusic()
        }
    }
    
    private func refreshSoundPlayers() {
        // Only reload if soundPools are empty to prevent disrupting active sounds
        if soundPools.isEmpty {
            preloadAllSounds()
        }
    }
    
    @objc private func appDidEnterBackground() {
        pauseBackgroundMusic()
//        for (_, players) in soundPools {
//            players.forEach { $0.pause() }
//        }

        // Deactivate so we don’t hold on to the session while in background.
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
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
            print("Error preloading sound \(sound.fileName): \(error.localizedDescription)")
#endif
        }
    }
    
    func setVolume(for sound: Sound, volume: Float) {
        guard let pool = soundPools[sound] else {
#if DEBUG
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
    func playSound(_ sound: Sound) {
        // If there's no pool or it's empty, create it now
        if soundPools[sound] == nil || soundPools[sound]!.isEmpty {
            preloadSound(sound, poolSize: decidePoolSize(for: sound))
        }
        
        // Now grab the pool (it should exist after preloadSound, but just in case)
        guard let pool = soundPools[sound] else {
    #if DEBUG
            print("No pool found for sound: \(sound)")
    #endif
            return
        }
        
        // Try to reuse an idle player
        if let player = pool.first(where: { !$0.isPlaying }) {
            player.currentTime = 0
            player.play()
        } else {
            // Optional: Dynamically create a new player if we haven't hit max pool size
            let maxPoolSize = 20 // Adjust as needed
            if pool.count < maxPoolSize {
                guard let url = Bundle.main.url(forResource: sound.fileName, withExtension: sound.fileExtension) else {
    #if DEBUG
                    print("Sound file \(sound.fileName).\(sound.fileExtension) not found.")
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
                    print("Error creating new player for sound \(sound): \(error.localizedDescription)")
    #endif
                }
            } else {
    #if DEBUG
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
    
    // MARK: - Background Music Controls
    
    /// Plays background music from the specified file.
    /// - Parameters:
    ///   - music: The background music to play, defined in the BackgroundMusic enum.
    ///   - loop: Whether the music should loop indefinitely.
    func playBackgroundMusic(_ music: BackgroundMusic, targetVolume: Float? = nil, loop: Bool = true, fadeDuration: TimeInterval? = 2.0) {
        // Stop any currently playing background music
        stopBackgroundMusic()
        
        guard let url = Bundle.main.url(forResource: music.rawValue, withExtension: music.fileExtension) else {
#if DEBUG
            print("Background music file \(music.rawValue).\(music.fileExtension) not found.")
#endif
            return
        }
        
        do {
            backgroundMusicPlayer = try AVAudioPlayer(contentsOf: url)
            backgroundMusicPlayer?.numberOfLoops = loop ? -1 : 0
            backgroundMusicPlayer?.volume = 0.0 // Start at 0 for fade-in
            backgroundMusicPlayer?.prepareToPlay()
            backgroundMusicPlayer?.play()
            isBackgroundMusicPlaying = true
            currentBackgroundMusic = music
            
            // Perform fade-in
            fadeInBackgroundMusic(targetVolume: targetVolume ?? 1.0, fadeDuration: fadeDuration ?? 0)
        } catch {
#if DEBUG
            print("Error playing background music \(music.rawValue): \(error.localizedDescription)")
#endif
        }
    }
    
    private func fadeInBackgroundMusic(targetVolume: Float, fadeDuration: TimeInterval) {
        guard let player = backgroundMusicPlayer else { return }
        
        let steps = 20
        let stepDuration = fadeDuration / Double(steps)
        let volumeIncrement = targetVolume / Float(steps)
        
        for step in 1...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + stepDuration * Double(step)) {
                player.volume += volumeIncrement
                if player.volume > targetVolume {
                    player.volume = targetVolume
                }
            }
        }
    }

    /// Pauses the currently playing background music.
    func pauseBackgroundMusic() {
        backgroundMusicPlayer?.pause()
        isBackgroundMusicPlaying = false
    }
    
    /// Resumes the currently paused background music.
    func resumeBackgroundMusic() {
        backgroundMusicPlayer?.play()
        isBackgroundMusicPlaying = true
    }
    
    /// Stops the currently playing background music.
    func stopBackgroundMusic(fade: Bool = false, fadeDuration: TimeInterval = 2.0) {
        guard let player = backgroundMusicPlayer, isBackgroundMusicPlaying else { return }
        
        if fade {
            fadeOutBackgroundMusic(player: player, duration: fadeDuration) { [weak self] in
                self?.backgroundMusicPlayer?.stop()
                self?.backgroundMusicPlayer = nil
                self?.isBackgroundMusicPlaying = false
                self?.currentBackgroundMusic = nil
            }
        } else {
            player.stop()
            backgroundMusicPlayer = nil
            isBackgroundMusicPlaying = false
            currentBackgroundMusic = nil
        }
    }

    private func fadeOutBackgroundMusic(player: AVAudioPlayer, duration: TimeInterval, completion: @escaping () -> Void) {
        let steps = 20
        let stepDuration = duration / Double(steps)
        let volumeDecrement = player.volume / Float(steps)
        
        for step in 1...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + stepDuration * Double(step)) {
                player.volume -= volumeDecrement
                if step == steps {
                    completion()
                }
            }
        }
    }
    /// Changes the background music to a new track.
    /// - Parameter music: The new background music to play.
    func changeBackgroundMusic(to music: BackgroundMusic) {
        playBackgroundMusic(music)
    }
}
