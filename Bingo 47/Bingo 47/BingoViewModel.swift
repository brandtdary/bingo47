//
//  BingoViewModel.swift
//  Bingo 47
//
//  Created by Brandt Dary on 1/15/25.
//


import SwiftUI
import AVFoundation
import StoreKit
import GameKit

// ViewModel to handle the game logic
class BingoViewModel: ObservableObject {
    private let soundManager = SoundManager.shared
    
    @Published var isGameActive: Bool = false
    @Published var bingoCards: [BingoCard] = [] // Multiple Bingo cards
    @Published var calledSpaces: Set<BingoSpace> = []
    @Published var currentSpace: BingoSpace? = nil // Current number being called
    @Published var currentGameWinnings: Int = 0
    @Published var payoutTable: [Payout] = []
    @Published var isLastCallActive: Bool = false
    @Published var lastCallSecondsRemaining: Int = 5
    @Published var availableProducts: [Product] = []
    @Published var isProcessingPurchase: Bool = false
    @Published var activeBingoSpaceColor: Color = .yellow
    @Published var activeDauberColor: Color = .green
    @Published var showGameModeSelection: Bool = !UserDefaults.standard.bool(forKey: GameSettingsKeys.hasSeenGameModeSelection)
    
    // MARK: BONUS
    @Published var showJackpotSheet: Bool = false
    @Published var lastJackpotAmount: Int = 0
    @Published var lastJackpotCount: Int = 0
    @Published var showJackpotAnimation: Bool = false
    @Published var animatedJackpotCount: Int = 0
    
    @Published var errorMessages: [String] = []
    
    
    // MARK: REWARDED BONUS BALLS
    @Published var bonusBallsOffer: Int? = nil // Current offer (5-10 balls)
    @Published var bonusBallOfferGamesRemaining: Int = 0 // Countdown before removal
    @Published var bonusBallOfferCooldown: Int = 0 // Countdown until next offer
    
    @Published var showRewardedAdButton: Bool = false
    
    var hasBonusSpaceBeenMarked: Bool {
        return bingoCards.contains { $0.markedSpaces.contains { $0.id == BingoViewModel.bonusSpaceID } }
    }
    
    // MARK: Game Center
    @Published var isAuthenticated = false

    var gameSpeed: GameSpeedOption {
        get { GameSpeedOption(rawValue: storedGameSpeed) ?? .normal }
        set {
            storedGameSpeed = newValue.rawValue

            // Disable speaking numbers if the speed is fast or lightning
            if newValue == .fast || newValue == .lightening {
                speakSpaces = false
            }
        }
    }
    
    var currentBet: Int {
        baseBet * betMultiplier
    }
    
    @AppStorage("userCredits") var credits: Int = 500 // Persisted credits using @AppStorage
    @AppStorage("savedBingoCards") private var savedBingoCardData: String = ""
    @AppStorage("favoriteBingoCards") private var favoriteBingoCardsData: String = ""
    @AppStorage("bingoSpaceColorChoice") var bingoSpaceColorChoice: String = BingoColor.yellow.rawValue
    @AppStorage("dauberColorChoice") var dauberColorChoice: String = BingoColor.red.rawValue
    @AppStorage("numberOfGamesPlayed") var numberOfGamesPlayed: Int = 0
    @AppStorage("numberOfBingos") var numberOfBingos: Int = 0
    @AppStorage("betMultiplier") var betMultiplier: Int = 1 // Bet multiplier
    
    
    @AppStorage(GameSettingsKeys.speakSpaces) var speakSpaces: Bool = true
    @AppStorage(GameSettingsKeys.autoMark) var autoMark: Bool = false
    @AppStorage(GameSettingsKeys.gameSpeed) private var storedGameSpeed: Double = GameSpeedOption.normal.rawValue
    @AppStorage(GameSettingsKeys.vibrationEnabled) var vibrationEnabled: Bool = true
    @AppStorage(GameSettingsKeys.gracefulBingos) var gracefulBingos: Bool = false
    
    private var gameTimer: Timer?
    private var lastCallTimer: Timer?
    private var preGeneratedSpaces: [BingoSpace] = [] // Store BingoSpace objects
    private let minimumBingosForPayout = 1
    private let betMultipliers = [1, 2, 5, 10, 25, 100, 500, 1000, 5000, 10_000, 25_000, 100_000, 1_000_000, 10_000_000]
    private var previousBingos = 0
    private let jackpotStorageKey = "jackpotStorage"
    static let bonusSpaceID = "47"
    
//    let rewardAdUnitID = "ca-app-pub-3940256099942544/1712485313" // TEST
    let rewardAdUnitID = "ca-app-pub-6362408680341882/7080298722" // REAL
    
    @MainActor
    private(set) var rewardedAdViewModel: RewardedAdViewModel?
    
    var jackpotStorage: [Int: Int] {
        get {
            guard let storedData = UserDefaults.standard.dictionary(forKey: jackpotStorageKey) as? [String: Int] else {
                return [:] // Default to empty dictionary
            }
            return storedData.reduce(into: [:]) { result, item in
                if let key = Int(item.key) {
                    result[key] = item.value
                }
            }
        }
        set {
            let convertedDict = newValue.reduce(into: [String: Int]()) { result, item in
                result[String(item.key)] = item.value
            }
            UserDefaults.standard.setValue(convertedDict, forKey: jackpotStorageKey)
        }
    }

    var synth: AVSpeechSynthesizer?

    let freeRefillAmount = 10000
    let baseBet = 100 // Base cost per game
    let blackOutWinAmount = 200 // 200x their bet

    let allSpaces: [BingoSpace] = [
        1, 2, 3, 4, 5, 6,
        16, 17, 18, 19, 20, 21,
        31, 32, 33, 34, 35, 36,
        46, 47, 48, 49, 50, 51,
        61, 62, 63, 64, 65, 66
    ].map { BingoSpace(id: "\($0)", isFreeSpace: false, label: "\($0)") }

    let bingoPatterns: [[Int]] = [
            [0, 1, 2], // Top row
            [3, 4, 5], // Middle row
            [6, 7, 8], // Bottom row
            [0, 3, 6], // Left column
            [1, 4, 7], // Middle column
            [2, 5, 8], // Right column
            [0, 4, 8], // Diagonal top-left to bottom-right
            [2, 4, 6]  // Diagonal top-right to bottom-left
        ]
    
    let defaultNumbersToDraw: Int = 15
    private(set) var numbersToDraw: Int = 15
    private(set) var bonusBalls: Int = 0

    init() {
        observeErrors()
        resetGame()
        loadOrGenerateCards()
        
        animatedJackpotCount = jackpotStorage[betMultiplier, default: betMultiplier * 20]
        
        Task { @MainActor in
            self.checkBonusBallOffer()
            self.rewardedAdViewModel = RewardedAdViewModel(adUnitID: rewardAdUnitID)
        }
        
        Task {
            await fetchIAPProducts()
        }

        payoutTable = generatePayoutTable()
                
        prepareSynthesizer()
        
        // Observe app lifecycle changes
        NotificationCenter.default.addObserver(self, selector: #selector(appDidEnterBackground), name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appDidBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
        
        if !UserDefaults.standard.bool(forKey: GameSettingsKeys.hasSeenGameModeSelection) {
            showGameModeSelection = true
        }
    }
    
    @objc private func appDidEnterBackground() {
        if isGameActive {
            pauseGameTimer()
        }
        if isLastCallActive {
            pauseLastCallTimer()
        }
    }
    
    @objc private func appDidBecomeActive() {
        if isGameActive {
            resumeGameTimer()
        }
        if isLastCallActive {
            resumeLastCallTimer()
        }
    }
    
    private var lastCallTimeRemaining: Int = 0

    private func pauseGameTimer() {
        if let timer = gameTimer {
            timer.invalidate()
            gameTimer = nil
        }
    }
    private func pauseLastCallTimer() {
        if let timer = lastCallTimer {
            lastCallTimeRemaining = lastCallSecondsRemaining
            timer.invalidate()
            lastCallTimer = nil
        }
    }
    
    private func resumeGameTimer() {
        guard isGameActive, calledSpaces.count < numbersToDraw else { return }
        revealNextSpace()
        startGameTimer()
    }

    private func resumeLastCallTimer() {
        guard isLastCallActive, lastCallTimeRemaining > 0 else { return }

        lastCallSecondsRemaining = lastCallTimeRemaining
        lastCallTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            guard let self = self else { return }

            if self.lastCallSecondsRemaining > 0 {
                self.lastCallSecondsRemaining -= 1
            } else {
                timer.invalidate()
                self.lastCallTimer = nil
                self.endLastCall()
            }
        }
    }
    
    private func loadOrGenerateCards() {
        if let decodedCards = decodeSavedCards() {
            bingoCards = decodedCards
        } else {
            let newCard = generateBingoCard()
            bingoCards = [newCard]
            saveCards(bingoCards)
        }
    }

    private func decodeSavedCards() -> [BingoCard]? {
        guard !savedBingoCardData.isEmpty,
              let data = savedBingoCardData.data(using: .utf8) else { return nil }

        return try? JSONDecoder().decode([BingoCard].self, from: data)
    }
    
    func setBingoCards(_ newCards: [BingoCard]) {
        bingoCards = newCards
        saveCards(newCards)
    }


    private func saveCards(_ cards: [BingoCard]) {
        if let encodedData = try? JSONEncoder().encode(cards),
           let jsonString = String(data: encodedData, encoding: .utf8) {
            savedBingoCardData = jsonString
        }
    }

    
    func resetCredits() {
        credits = freeRefillAmount
        soundManager.playSound(.freeChips)
    }
    
    @MainActor
    func addCredits(_ amount: Int) {
        credits += amount
    }
    
    /// Fetch available IAP products and store them
    func fetchIAPProducts() async {
        do {
            let products = try await IAPManager.shared.fetchProducts()
            await MainActor.run { self.availableProducts = products }
        } catch {
            print("⚠️ Error fetching products: \(error.localizedDescription)")
        }
    }

    /// Initiates a purchase and updates credits upon success
    @MainActor
    func purchaseCredits(productID: String) async {
        isProcessingPurchase = true
        
        do {
            let success = try await IAPManager.shared.purchase(productID: productID)
            if success {
                self.addCredits(for: productID)
                self.isProcessingPurchase = false
            } else {
                print("⚠️ Purchase was canceled or pending")
                self.isProcessingPurchase = false
            }
        } catch {
            self.isProcessingPurchase = false
            print("⚠️ Purchase failed: \(error.localizedDescription)")
        }
    }
    
    /// Increases credits based on product ID
    private func addCredits(for productID: String) {
        switch productID {
        case IAPManager.productCreditsTier1ID: credits += 10_000
        case IAPManager.productCreditsTier2ID: credits += 100_000
        case IAPManager.productCreditsTier3ID: credits += 1_000_000
        default: print("⚠️ Unknown product ID: \(productID)")
        }
        soundManager.playSound(.purchasedChips)
    }

    func resetGame() {
        stopTimer()
        calledSpaces = []
        currentSpace = nil
        preGeneratedSpaces = []
        currentGameWinnings = 0
        
        for index in bingoCards.indices {
            bingoCards[index].markedSpaces.removeAll()
        }
        
        previousBingos = 0
    }
    
    func stopTimer() {
        gameTimer?.invalidate()
        gameTimer = nil
    }
    
    @MainActor func toggleBetMultiplier() {
        guard gameTimer == nil else { return } // Prevent changing bet during an active game
        
        resetGame() // Reset the game state
        soundManager.playSound(.beepUp) // Play a beep sound
        HapticManager.shared.triggerHaptic(for: .soft) // Trigger a soft haptic feedback
        
        // Find the current index of the betMultiplier in the betMultipliers array
        if let currentIndex = betMultipliers.firstIndex(of: betMultiplier) {
            let nextIndex = (currentIndex + 1) % betMultipliers.count
            betMultiplier = betMultipliers[nextIndex]
        } else {
            betMultiplier = betMultipliers.first ?? 1
        }

        payoutTable = generatePayoutTable()
        
        // Update animated jackpot count based on new bet multiplier
        animatedJackpotCount = jackpotStorage[betMultiplier, default: betMultiplier * 20]
    }

    @MainActor func lowerBetToMaxPossible() {
        let sortedMultipliers = betMultipliers.sorted(by: >)
        
        if let maxMultiplier = sortedMultipliers.first(where: { baseBet * $0 <= credits }) {
            betMultiplier = maxMultiplier
        } else {
            betMultiplier = betMultipliers.first ?? 1
        }
        
        payoutTable = generatePayoutTable()
        
        soundManager.playSound(.beepDown)
        HapticManager.shared.triggerHaptic(for: .soft)
        
        // Update animated jackpot count after lowering bet
        animatedJackpotCount = jackpotStorage[betMultiplier, default: betMultiplier * 20]
    }

    
    func toggleAutoMark() {
        autoMark.toggle()
    }
    
    func generateNewCard() {
        guard !isGameActive else { return }
        HapticManager.shared.triggerHaptic(for: .choose)
        resetGame()
        bingoCards = generateBingoCards(count: 1)
        saveCards(bingoCards)
    }

    func generateBingoCards(count: Int) -> [BingoCard] {
        (1...count).map { _ in generateBingoCard() }
    }

    func generateBingoCard() -> BingoCard {
        var spaces: [BingoSpace] = []
        let shuffledNumbers = self.allSpaces.filter { $0.label != Self.bonusSpaceID }.shuffled()

        for i in 0..<9 {
            let label = (i == 4) ? Self.bonusSpaceID : "\(shuffledNumbers[i].label)"
            let space = BingoSpace(id: label, isFreeSpace: false, label: label) // No more free space!
            spaces.append(space)
        }
        
        return BingoCard(rows: 3, columns: 3, spaces: spaces)
    }
    
    // MARK: Game Center
    func submitScoreToLeaderboard(score: Int) {
        let leaderboardID = "com.gudmilk.bingo47.leaderboards.credits"  
        guard GKLocalPlayer.local.isAuthenticated else {
                print("Local player is not authenticated")
                return
            }

            GKLeaderboard.submitScore(
                score,
                context: 0,
                player: GKLocalPlayer.local,
                leaderboardIDs: [leaderboardID]
            ) { error in
                if let error = error {
                    print("Error submitting score: \(error.localizedDescription)")
                }
            }
    }
    
    // MARK: USER ACTIONS
    
    // MARK: PLAY GAME
    @MainActor func beginGame() {
        guard isGameActive == false else { return }
        isGameActive = true
        
        assignColorsForCurrentGame()
        HapticManager.shared.triggerHaptic(for: .choose)

        guard credits >= baseBet * betMultiplier else { return } // Ensure user has enough credits

        credits -= baseBet * betMultiplier // Deduct credits
        resetGame() // Reset game state for a new game
                
        numbersToDraw = defaultNumbersToDraw + bonusBalls
        bonusBalls = 0
        
        checkBonusBallOffer()
        
        preGeneratedSpaces = Array(allSpaces.shuffled().prefix(min(numbersToDraw, allSpaces.count))) // Generate exact sequence
        calledSpaces = [] // Reset called spaces
        
        DispatchQueue.main.asyncAfter(deadline: .now() + (0.5)) { [weak self] in
            guard let self = self else { return }
            self.startGameTimer()
        }
    }
    
    private func startGameTimer() {
        gameTimer?.invalidate()

        // Start the timer for revealing subsequent numbers
        gameTimer = Timer.scheduledTimer(withTimeInterval: gameSpeed.rawValue, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }

            self.revealNextSpace()

            if self.calledSpaces.count == self.numbersToDraw {
                self.handleGameEnd()
            }
        }
    }
    
    private func startLastCall() {
        isLastCallActive = true
        lastCallSecondsRemaining = 10 // since we're updating the timer every quarter second... this is to ensure that if they've marked all their spaces, we take action quickly.

        lastCallTimer?.invalidate()
        lastCallTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] timer in
            guard let self = self else { return }
            
            if lastCallSecondsRemaining > 0 {
                lastCallSecondsRemaining -= 1
            } else {
                timer.invalidate()
                lastCallTimer = nil
                endLastCall()
            }
        }
    }
    
    private func endLastCall() {
        isLastCallActive = false
        lastCallTimer?.invalidate()
        lastCallTimer = nil

        if gracefulBingos {
            autoMarkUnmarkedNumbers()
        }

        finalizeGame()
    }
    
    /// Adds to the jackpot and animates the count increase
    func addToJackpotWithAnimation() {
        let currentCount = jackpotStorage[betMultiplier, default: betMultiplier * 20]
        let newCount = currentCount + betMultiplier
        jackpotStorage[betMultiplier] = newCount

        lastJackpotCount = newCount
        animatedJackpotCount = currentCount
        showJackpotAnimation = true // Make the animation view visible

        // Determine animation speed based on amount change
        let duration = getAnimationDuration(for: betMultiplier)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.incrementJackpotCount(to: newCount, duration: duration)
        }
    }

    /// Animates the jackpot count increment one-by-one
    private func incrementJackpotCount(to finalValue: Int, duration: Double) {
        let totalIncrements = min(100, finalValue - animatedJackpotCount)
        let aproximateStep = Int((finalValue - animatedJackpotCount) / totalIncrements)
        guard totalIncrements > 0 else { return }

        let incrementInterval = duration / Double(totalIncrements)

        DispatchQueue.global(qos: .userInitiated).async {
            for i in 1...totalIncrements {
                DispatchQueue.main.asyncAfter(deadline: .now() + (incrementInterval * Double(i))) {
                    self.animatedJackpotCount += aproximateStep
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + (duration * 1.05)) {
                self.animatedJackpotCount = finalValue
            }
        }
    }

    /// Determines animation duration based on amount change
    private func getAnimationDuration(for amount: Int) -> Double {
        switch amount {
        case 0..<21: return 0.75
        case 21...: return 1.5
        default: return 3.0
        }
    }

    private func claimJackpot() {
        let jackpotCount = jackpotStorage[betMultiplier, default: lastJackpotCount]
        let totalPrize = jackpotCount * 47
        
        if jackpotCount > 0 {
            let jackpotStartingPoint = betMultiplier * 20
            credits += totalPrize
            lastJackpotAmount = totalPrize
            lastJackpotCount = jackpotCount
            showJackpotSheet = true
            
            jackpotStorage[betMultiplier] = jackpotStartingPoint // Reset jackpot
            animatedJackpotCount = jackpotStorage[betMultiplier] ?? jackpotStartingPoint
        }
    }

    func checkForBlackout() {
        if bingoCards.allSatisfy({ $0.markedSpaces.count == $0.spaces.count }) {
            claimJackpot()
        }
    }

    
    private func revealNextSpace() {
        guard let nextSpace = preGeneratedSpaces.first else { return }

        preGeneratedSpaces.removeFirst()
        calledSpaces.insert(nextSpace)
        currentSpace = nextSpace
        
        if speakSpaces {
            speak(text: labelForSpeach(space: nextSpace))
        }

        if autoMark {
            for card in bingoCards {
                markSpace(nextSpace, cardID: card.id)
            }
        } else {
            soundManager.playSound(.called)
        }
    }
    
    // MARK: Mark Space
    func markSpace(_ space: BingoSpace, cardID: UUID) {
        guard isGameActive else { return } // Ensure the game is active
        guard let cardIndex = bingoCards.firstIndex(where: { $0.id == cardID }) else { return }
        let card = bingoCards[cardIndex]
        let numberIsOnCard = card.spaces.contains(space)
        
        guard calledSpaces.contains(space) else {
            soundManager.playSound(.markedNotCalled)
            HapticManager.shared.triggerHaptic(for: .wrongNumber)
            return
        }
        
        if space.id == Self.bonusSpaceID {
            addToJackpotWithAnimation()
//                addToJackpot()
        }

        if numberIsOnCard, let index = bingoCards.firstIndex(where: { $0.id == cardID }) {
            var mutableCard = bingoCards[index]
            
            if !mutableCard.markedSpaces.contains(space) {
                mutableCard.markedSpaces.insert(space)
            }
            
            bingoCards[index] = mutableCard
            calculateResults()
        }
        
        playSoundForSpaceMarked(space, card: card)
        
        if isLastCallActive && !hasUnmarkedCalledSpaces() {
            endLastCall()
        }
    }
    
    private func autoMarkUnmarkedNumbers() {
        for index in bingoCards.indices {
            for space in bingoCards[index].spaces where calledSpaces.contains(space) {
                if !bingoCards[index].markedSpaces.contains(space) {
                    bingoCards[index].markedSpaces.insert(space)
                }
            }
        }
    }
    
    fileprivate func playSoundForSpaceMarked(_ nextSpace: BingoSpace, card: BingoCard) {
        let currentBingos = calculateBingos(for: bingoCards.first!)
        
        if nextSpace.isFreeSpace {
            soundManager.playSound(.welcome)
            HapticManager.shared.triggerHaptic(for: .choose)
        } else if isBonusSpace(nextSpace) {
            HapticManager.shared.triggerHaptic(for: .bingo)
            SoundManager.shared.playSound(.go)
        } else if previousBingos < currentBingos {
            soundManager.playSound(.bingo)
            HapticManager.shared.triggerHaptic(for: .bingo)
        } else if bingoCards.first?.spaces.contains(nextSpace) ?? false {
            soundManager.playSound(.welcome)
        } else {
            soundManager.playSound(.called)
//            HapticManager.shared.triggerHaptic(for: .light)
        }
        
        previousBingos = currentBingos
    }
    
    func speak(text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        
        synth?.speak(utterance)
    }
    
    func prepareSynthesizer() {
        if synth == nil {
            synth = AVSpeechSynthesizer()
        }
        let utterance = AVSpeechUtterance(string: " ") // Silent utterance
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        synth?.speak(utterance)
    }

    
    func isPartOfBingo(_ space: BingoSpace, for card: BingoCard) -> Bool {
        let bingoSpaces = findBingoSpaces(for: card) // Get all spaces in a winning pattern
        return bingoSpaces.contains(space)
    }
    
    private func finalizeGame() {
        lastCallTimer?.invalidate()
        lastCallTimer = nil
        
        checkForBlackout() // Check if blackout occurred after marking

        isGameActive = false
        numberOfGamesPlayed += 1
        credits += currentGameWinnings
        
        if bonusBallsOffer == nil && Int.random(in: 1...100) > 25 { // 75% chance of bonus
            bonusBalls = [1,2,2,3,3].randomElement() ?? 1
        }
        
        submitScoreToLeaderboard(score: credits)
    }
        
    @MainActor
    func tryShowingRewardedAd() {
        guard let offer = bonusBallsOffer else {
            ErrorManager.log("❌ No Offer Available...")
            return
        }

        guard let rewardedAdViewModel = rewardedAdViewModel else {
            ErrorManager.log("❌ No Ad Model Found - Rewarding Anyway")
            rewardUser(with: offer)
            return
        }
        
        if rewardedAdViewModel.isAdReady {
            ErrorManager.log("✅ Ad Is Ready")
            rewardedAdViewModel.showAd {
                ErrorManager.log("✅ Ad was shown")
                self.rewardUser(with: offer)
            }
        } else {
            ErrorManager.log("❌ Ad Not Ready - Loading New Ad")
            rewardedAdViewModel.loadAd() // ✅ Try loading the ad immediately
            rewardUser(with: offer)       // Reward the user even though the ad wasn't ready
        }
        
        showRewardedAdButton = false // Hide the button immediately after tap
    }

    // ✅ Centralized reward logic
    private func rewardUser(with offer: Int) {
        ErrorManager.log("✅ Rewarding User with \(offer) balls")
        bonusBalls += offer
        bonusBallsOffer = nil
        showRewardedAdButton = false
        soundManager.playSound(.adReward)
    }
    
    func handleGameEnd() {
        stopTimer()

        let unmarkedCalledNumbers = bingoCards.flatMap { card in
            card.spaces.filter { space in
                calledSpaces.contains(space) && !space.isFreeSpace && !card.markedSpaces.contains(space)
            }
        }

        if unmarkedCalledNumbers.isEmpty {
            finalizeGame()
        } else {
            startLastCall()
        }
    }
    
    func labelForSpeach(space: BingoSpace) -> String {
//        let numberString = space.label
        return space.label
    }

    // Helper method to determine column based on number
    private func column(for number: String) -> String {
        guard let num = Int(number) else { return "" }

        switch num {
        case 1...15:
            return "B"
        case 16...30:
            return "I"
        case 31...45:
            return "N"
        case 46...60:
            return "G"
        case 61...75:
            return "O"
        default:
            return ""
        }
    }

    func hasUnmarkedCalledSpaces() -> Bool {
        return bingoCards.flatMap { card in
            card.spaces.filter { space in
                calledSpaces.contains(space) && !space.isFreeSpace && !card.markedSpaces.contains(space)
            }
        }.isEmpty == false
    }
    
    func calculateBingos(for card: BingoCard) -> Int {
        let markedSpaces = card.markedSpaces
        var bingoCount = 0

        for pattern in bingoPatterns {
            if pattern.allSatisfy({ markedSpaces.contains(card.spaces[$0]) || card.spaces[$0].isFreeSpace }) {
                bingoCount += 1
            }
        }

        return bingoCount
    }

    
    func calculateResults() {
        let totalBingos = bingoCards.reduce(0) { $0 + calculateBingos(for: $1) }
        let winnings = payoutTable.first(where: { $0.bingos == totalBingos })?.win ?? 0

        numberOfBingos += totalBingos
        // Update current winnings
        currentGameWinnings = winnings
    }
    
    func calculatePayout(for bingos: Int) -> Int {
        let betAmount = baseBet * betMultiplier // Full bet amount

        if bingos <= 0 {
            return 0
        } else if bingos <= 2 {
            let percentage = bingos * 50
            return (betAmount * percentage) / 100
        } else {
            switch bingos {
            case 3:
                return betAmount * 2
            case 4:
                return betAmount * 3
            case 5:
                return betAmount * 5
            case 6:
                return betAmount * 10
            case 7:
                return betAmount * 20
            case 8:
                return betAmount * 47
            default:
                return betAmount * (1 << (bingos - 5)) // Exponential scaling for 9+ bingos
            }
        }
    }

    func generatePayoutTable() -> [Payout] {
        var table: [Payout] = []
        
        for bingos in minimumBingosForPayout...bingoPatterns.count {
            let win = calculatePayout(for: bingos)
            table.append(Payout(bingos: bingos, win: win))
        }
        
        return table
    }
    
    func findBingoSpaces(for card: BingoCard) -> Set<BingoSpace> {
        let markedSpaces = card.markedSpaces
        var bingoSpaces: Set<BingoSpace> = []

        // Loop through each bingo pattern
        for pattern in bingoPatterns {
            // Check if all positions in the pattern are marked
            if pattern.allSatisfy({ markedSpaces.contains(card.spaces[$0]) }) {
                // If this pattern is a bingo, add all its spaces to the bingoSpaces set
                bingoSpaces.formUnion(pattern.map { card.spaces[$0] })
            }
        }

        return bingoSpaces
    }
    
    // MARK: HELPERS
    func hasSpaceBeenCalled(_ spaceID: String) -> Bool {
        guard isGameActive else { return false }
        return calledSpaces.contains { $0.id == spaceID }
    }
    
    func shouldShowJackpotDisplay() -> Bool  {
        return !isGameActive || hasBonusSpaceBeenMarked
    }
    
    func isBonusSpace(_ space: BingoSpace) -> Bool {
        return space.id == BingoViewModel.bonusSpaceID
    }
    
    @MainActor
    func checkBonusBallOffer() {
        let adIsReady = rewardedAdViewModel?.isAdReady == true
        
        if bonusBallOfferGamesRemaining > 0 {
            bonusBallOfferGamesRemaining -= 1
            if bonusBallOfferGamesRemaining == 0 {
                bonusBallsOffer = nil
                bonusBallOfferCooldown = Int.random(in: 5...10) // Wait before new offer
            }
        } else if bonusBallOfferCooldown > 0 {
            bonusBallOfferCooldown -= 1
        } else if adIsReady {
            bonusBallsOffer = [5,5,5,6,6,7].randomElement()!
            bonusBallOfferGamesRemaining = 3
        }
        
        showRewardedAdButton = (bonusBallsOffer != nil && adIsReady)
    }
    
    // MARK: Error Handling
    private func observeErrors() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleError(_:)), name: .errorNotification, object: nil)
    }

    @objc private func handleError(_ notification: Notification) {
        if let errorMessage = notification.userInfo?["message"] as? String {
            DispatchQueue.main.async {
                self.errorMessages.append(errorMessage)
            }
        }
    }

    func dismissError(at index: Int) {
        DispatchQueue.main.async {
            self.errorMessages.remove(at: index)
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self, name: .errorNotification, object: nil)
    }

}

extension BingoViewModel {
    var bingoSpaceColor: Color {
        BingoColor(rawValue: bingoSpaceColorChoice)?.color ?? .red
    }
    
    var dauberColor: Color {
        BingoColor(rawValue: dauberColorChoice)?.color ?? .blue
    }
    
    private func assignColorsForCurrentGame() {
        // If user’s menu pick is random
        if bingoSpaceColorChoice == BingoColor.random.rawValue {
            // pick a random color from real options, e.g. .red, .blue, etc.
            let realOptions = BingoColor.allCases.filter { $0 != .random }
            let randomChoice = realOptions.randomElement() ?? .yellow
            activeBingoSpaceColor = randomChoice.color
        } else {
            // Otherwise just convert the user’s saved string into a real color
            let chosen = BingoColor(rawValue: bingoSpaceColorChoice) ?? .yellow
            activeBingoSpaceColor = chosen.color
        }
        
        // Same for dauber
        if dauberColorChoice == BingoColor.random.rawValue {
            let realOptions = BingoColor.allCases.filter { $0 != .random }
            // You could further ensure it differs from activeBingoSpaceColor if you like
            let filtered = realOptions.filter { $0.rawValue != bingoSpaceColorChoice }
            let randomChoice = filtered.randomElement() ?? .green
            activeDauberColor = randomChoice.color
        } else {
            let chosen = BingoColor(rawValue: dauberColorChoice) ?? .green
            activeDauberColor = chosen.color
        }
    }
}

extension BingoViewModel {
    // Returns the currently stored favorites
    var favoriteBingoCards: [BingoCard] {
        get {
            guard !favoriteBingoCardsData.isEmpty,
                  let data = favoriteBingoCardsData.data(using: .utf8),
                  let decoded = try? JSONDecoder().decode([BingoCard].self, from: data)
            else {
                return []
            }
            return decoded
        }
        set {
            if let encodedData = try? JSONEncoder().encode(newValue),
               let jsonString = String(data: encodedData, encoding: .utf8) {
                favoriteBingoCardsData = jsonString
            }
        }
    }

    // Convenience method to add a BingoCard to favorites if not already there
    func favoriteCard(_ card: BingoCard) {
        var currentFavorites = favoriteBingoCards
        if !currentFavorites.contains(where: { $0.id == card.id }) {
            currentFavorites.append(card)
            favoriteBingoCards = currentFavorites
        }
    }
    
    // If you ever want to remove a card from favorites:
    func removeCardFromFavorites(_ card: BingoCard) {
        var currentFavorites = favoriteBingoCards
        currentFavorites.removeAll(where: { $0.id == card.id })
        favoriteBingoCards = currentFavorites
    }
}

enum GameSpeedOption: Double, CaseIterable {
    case slow = 3.5
    case normal = 2.0
    case fast = 0.5
    case lightening = 0.15

    var label: String {
        switch self {
        case .slow:        return "Slow"
        case .normal:      return "Normal"
        case .fast:        return "Fast"
        case .lightening:  return "Lightening"
        }
    }

    var symbolName: String {
        switch self {
        case .slow:        return "tortoise"
        case .normal:      return "figure.walk"
        case .fast:        return "hare.fill"
        case .lightening:  return "bolt.fill"
        }
    }

    /// A custom color for the SF Symbol
    var symbolColor: Color {
        return .black
    }
}


// Define the BingoSpace struct
struct BingoSpace: Identifiable, Hashable, Codable {
    let id: String // Unique identifier, e.g., "1", "B1", or an emoji
    let isFreeSpace: Bool
    let label: String // Display label, could be redundant but useful for UI
}

// Define the BingoCard struct
struct BingoCard: Identifiable, Codable {
    let id: UUID
    let rows: Int
    let columns: Int
    let spaces: [BingoSpace]
    var markedSpaces: Set<BingoSpace> = []

    init(id: UUID = UUID(), rows: Int = 5, columns: Int = 5, spaces: [BingoSpace], markedSpaces: Set<BingoSpace> = []) {
        self.id = id
        self.rows = rows
        self.columns = columns
        self.spaces = spaces
        self.markedSpaces = markedSpaces
    }

    enum CodingKeys: String, CodingKey {
        case id, rows, columns, spaces
        // `markedSpaces` is intentionally left out
    }
}

struct Payout: Identifiable {
    let id = UUID() // Unique identifier for SwiftUI usage
    let bingos: Int // Number of bingos
    let win: Int    // Win amount
}

extension UIApplication {
    var rootViewController: UIViewController? {
        // Get the active scene
        guard let scene = connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first(where: { $0.isKeyWindow }) else {
            return nil
        }
        return window.rootViewController
    }
}

extension Int {
    private static let sharedFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 1
        return formatter
    }()

    private static let sharedSmallNumberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    
    func formatted(shortened: Bool = false) -> String {
        guard shortened else {
            return "\(Int.sharedFormatter.string(for: Double(self)) ?? "0")"
        }
        
        switch self {
        case 999..<100_000:
            return "\(Int.sharedSmallNumberFormatter.string(for: Double(self)) ?? "0")"
        case 100_000..<1_000_000:
            return "\(Int.sharedSmallNumberFormatter.string(for: Double(self) / 1_000) ?? "0") K"
        case 1_000_000..<1_000_000_000:
            return "\(Int.sharedFormatter.string(for: Double(self) / 1_000_000) ?? "0") M"
        case 1_000_000_000..<1_000_000_000_000:
            return "\(Int.sharedFormatter.string(for: Double(self) / 1_000_000_000) ?? "0") B"
        default:
            return "\(self)"
        }
    }
}
