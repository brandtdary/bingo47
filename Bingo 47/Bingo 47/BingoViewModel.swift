//
//  BingoViewModel.swift
//  Bingo Tap
//
//  Created by Brandt Dary on 1/15/25.
//


import SwiftUI
import AVFoundation
import StoreKit

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
    
    var gameSpeed: GameSpeedOption {
        get { GameSpeedOption(rawValue: storedGameSpeed) ?? .normal }
        set { storedGameSpeed = newValue.rawValue }
    }
    
    var currentBet: Int {
        baseBet * betMultiplier
    }
    
    @AppStorage("userCredits") var credits: Int = 500 // Persisted credits using @AppStorage
    @AppStorage("savedBingoCards") private var savedBingoCardData: String = ""
    @AppStorage("favoriteBingoCards") private var favoriteBingoCardsData: String = ""
    @AppStorage("bingoSpaceColorChoice") var bingoSpaceColorChoice: String = BingoColor.yellow.rawValue
    @AppStorage("dauberColorChoice") var dauberColorChoice: String = BingoColor.green.rawValue
    @AppStorage("numberOfGamesPlayed") var numberOfGamesPlayed: Int = 0
    @AppStorage("numberOfBingos") var numberOfBingos: Int = 0
    
    @AppStorage("betMultiplier") var betMultiplier: Int = 1 // Bet multiplier
    @AppStorage("speakSpaces") var speakSpaces: Bool = true
    @AppStorage("autoMark") var autoMark: Bool = false
    @AppStorage("gameSpeed") private var storedGameSpeed: Double = GameSpeedOption.normal.rawValue
    @AppStorage("vibrationEnabled") var vibrationEnabled: Bool = true
    @AppStorage("gracefulBingos") var gracefulBingos: Bool = false

    private var gameTimer: Timer?
    private var lastCallTimer: Timer?
    private var preGeneratedSpaces: [BingoSpace] = [] // Store BingoSpace objects
    private let minimumBingosForPayout = 1
    private let betMultipliers = [1, 2, 4, 8, 12, 20, 40, 80, 160, 200, 400, 800, 1200, 2000, 4000, 8000, 12000, 20000, 40000]
    private var previousBingos = 0
    
    var synth: AVSpeechSynthesizer?


    let baseBet = 25 // Base cost per game
    let blackOutWinAmount = 200 // 200x their bet
    let allSpaces: [BingoSpace] = (1...75).map { BingoSpace(id: "\($0)", isFreeSpace: false, label: "\($0)") }

    let bingoPatterns: [[Int]] = [
        // Horizontal rows
        [0, 1, 2, 3, 4],
        [5, 6, 7, 8, 9],
        [10, 11, 12, 13, 14],
        [15, 16, 17, 18, 19],
        [20, 21, 22, 23, 24],

        // Vertical columns
        [0, 5, 10, 15, 20],
        [1, 6, 11, 16, 21],
        [2, 7, 12, 17, 22],
        [3, 8, 13, 18, 23],
        [4, 9, 14, 19, 24],

        // Diagonals (excluding the center "FREE" space)
        [0, 6, 18, 24], // Top-left to bottom-right diagonal
        [4, 8, 16, 20]  // Top-right to bottom-left diagonal
    ]
    
    private(set) var numbersToDraw: Int = 60

    init() {
        resetGame()
        loadOrGenerateCards()
        
        Task {
            await fetchIAPProducts()
        }

        payoutTable = generatePayoutTable()
        
        // MARK: TODO Update this
        if credits < baseBet {
            credits = 100
        }
        
        prepareSynthesizer()
        
        // Observe app lifecycle changes
        NotificationCenter.default.addObserver(self, selector: #selector(appDidEnterBackground), name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(appDidBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
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
    
    private var gameTimeRemaining: TimeInterval = 0
    private var lastCallTimeRemaining: Int = 0
    private var lastPausedTime: Date?

    private func pauseGameTimer() {
        if let timer = gameTimer {
            lastPausedTime = Date()  // Store the time of pausing
            gameTimeRemaining = timer.fireDate.timeIntervalSince(Date()) // Store remaining time
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
        guard isGameActive, gameTimeRemaining > 0 else { return }

        if let lastPausedTime = lastPausedTime {
            let elapsedTime = Date().timeIntervalSince(lastPausedTime)
            gameTimeRemaining -= elapsedTime  // Adjust for elapsed time
        }

        if gameTimeRemaining > 0 {
            gameTimer = Timer.scheduledTimer(withTimeInterval: gameTimeRemaining, repeats: false) { [weak self] _ in
                self?.revealNextSpace()
                self?.startGameTimer() // Resume normal timer interval
            }
        } else {
            // If time already expired, proceed immediately
            revealNextSpace()
            startGameTimer()
        }
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
        credits = 100
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
        case IAPManager.productCreditsTier1ID: credits += 1000
        case IAPManager.productCreditsTier2ID: credits += 10000
        case IAPManager.productCreditsTier3ID: credits += 75000
        default: print("⚠️ Unknown product ID: \(productID)")
        }
        soundManager.playSound(.purchasedChips)
    }

    func resetGame() {
        stopTimer()
        calledSpaces = []
        currentSpace = nil
        preGeneratedSpaces = []
        currentGameWinnings = 0 // Reset winnings for the next game
        
        for index in bingoCards.indices {
            bingoCards[index].markedSpaces.removeAll()
        }
        
        previousBingos = 0
    }
    
    func stopTimer() {
        gameTimer?.invalidate()
        gameTimer = nil
    }
    
    func toggleBetMultiplier() {
        guard gameTimer == nil else { return } // Prevent changing bet during an active game
        
        resetGame() // Reset the game state
        soundManager.playSound(.beepUp) // Play a beep sound
        HapticManager.shared.triggerHaptic(for: .soft) // Trigger a soft haptic feedback
        
        // Find the current index of the betMultiplier in the betMultipliers array
        if let currentIndex = betMultipliers.firstIndex(of: betMultiplier) {
            // Calculate the next index, wrapping around to 0 if at the end
            let nextIndex = (currentIndex + 1) % betMultipliers.count
            betMultiplier = betMultipliers[nextIndex] // Update the betMultiplier to the next value
        } else {
            // If the current betMultiplier isn't found, default to the first multiplier
            betMultiplier = betMultipliers.first ?? 1
        }
        
        payoutTable = generatePayoutTable() // Re-generate the payout table based on the new bet
    }
    
    func lowerBetToMaxPossible() {
        // Sort betMultipliers in descending order
        let sortedMultipliers = betMultipliers.sorted(by: >)
        
        // Find the first multiplier where baseBet * betMultiplier <= credits
        if let maxMultiplier = sortedMultipliers.first(where: { baseBet * $0 <= credits }) {
            betMultiplier = maxMultiplier
        } else {
            // If no multiplier fits, set to minimum (e.g., 1)
            betMultiplier = betMultipliers.first ?? 1
        }
        
        // Update the payout table based on the new betMultiplier
        payoutTable = generatePayoutTable()
        
        // Optional: Provide feedback to the user
        soundManager.playSound(.beepDown) // Play a sound indicating bet has been lowered
        HapticManager.shared.triggerHaptic(for: .soft) // Trigger a soft haptic feedback
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
        let ranges = [
            1...15,   // B column
            16...30,  // I column
            31...45,  // N column (middle has "FREE")
            46...60,  // G column
            61...75   // O column
        ]
        
        var spaces: [BingoSpace] = []
        
        for (columnIndex, range) in ranges.enumerated() {
            var columnNumbers = Array(range).shuffled()
            
            if columnIndex == 2 { // N column needs a Free Space in the center
                columnNumbers = Array(columnNumbers.prefix(4)) // Take 4 numbers
            } else {
                columnNumbers = Array(columnNumbers.prefix(5)) // Take 5 numbers
            }
            
            for rowIndex in 0..<5 {
                let isFreeSpace = (columnIndex == 2 && rowIndex == 2) // Middle space in the N column
                let label: String
                if isFreeSpace {
                    label = "FREE"
                    spaces.append(BingoSpace(id: "FREE", isFreeSpace: true, label: label))
                } else {
                    label = "\(columnNumbers[rowIndex >= 2 && columnIndex == 2 ? rowIndex - 1 : rowIndex])"
                    spaces.append(BingoSpace(id: label, isFreeSpace: false, label: label))
                }
            }
        }
        
        return BingoCard(spaces: spaces)
    }
    
    // MARK: USER ACTIONS
    
    // MARK: PLAY GAME
    func beginGame() {
        guard isGameActive == false else { return }
        isGameActive = true
        
        assignColorsForCurrentGame()
        HapticManager.shared.triggerHaptic(for: .choose)

        guard credits >= baseBet * betMultiplier else { return } // Ensure user has enough credits

        credits -= baseBet * betMultiplier // Deduct credits
        resetGame() // Reset game state for a new game

        // Pre-generate the sequence of numbers to draw
        numbersToDraw = 60 // Int.random(in: 55...65)
        preGeneratedSpaces = Array(allSpaces.shuffled().prefix(numbersToDraw)) // Generate exact sequence
        calledSpaces = [] // Reset called spaces

        if autoMark {
            for card in bingoCards {
                if let freeSpace = card.spaces.first(where: { $0.isFreeSpace }) {
                    markSpace(freeSpace, cardID: card.id) // Mark the Free Space
                }
            }
        }
        
        self.revealNextSpace()

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
        guard space.isFreeSpace || calledSpaces.contains(space) else {
            soundManager.playSound(.markedNotCalled)
            HapticManager.shared.triggerHaptic(for: .wrongNumber)
            return
        }
        

        // Find the card by its ID
        if let index = bingoCards.firstIndex(where: { $0.id == cardID }) {
            var mutableCard = bingoCards[index] // Get a mutable copy of the card
            
            if !mutableCard.markedSpaces.contains(space) {
                mutableCard.markedSpaces.insert(space)
            }
            
            bingoCards[index] = mutableCard // Replace the modified card in the array
            calculateResults() // Update results if necessary
            playSoundForSpaceMarked(space, card: mutableCard)
        }
        
        // If last call is active and all numbers are now marked, end the game immediately
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
        // Play sounds based on match
        let currentBingos = calculateBingos(for: bingoCards.first!)
        
        if nextSpace.isFreeSpace {
            soundManager.playSound(.welcome)
            HapticManager.shared.triggerHaptic(for: .choose)
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
        isGameActive = false
        numberOfGamesPlayed += 1
        credits += currentGameWinnings
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
        let numberString = space.label
        let columnString = column(for: numberString)
        
        return "\(columnString) \(numberString)"
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
        // Directly calculate the payout based on the number of bingos
        switch bingos {
        case 1:
            return 2 * betMultiplier
        case 2:
            return 5 * betMultiplier
        case 3:
            return 10 * betMultiplier
        case 4:
            return 15 * betMultiplier
        case 5:
            return 1 * (baseBet * betMultiplier)
        case 6:
            return 2 * (baseBet * betMultiplier)
        case 7:
            return 4 * (baseBet * betMultiplier)
        case 8:
            return 8 * (baseBet * betMultiplier)
        case 9:
            return 15 * (baseBet * betMultiplier)
        case 10:
            return 30 * (baseBet * betMultiplier)
        case 11:
            return 40 * (baseBet * betMultiplier)
        case 12:
            // Blackout payout
            return blackOutWinAmount * (baseBet * betMultiplier)
        default:
            return 0
        }
    }

    func generatePayoutTable() -> [Payout] {
        var table: [Payout] = []
        for bingos in minimumBingosForPayout...12 {
            let win = calculatePayout(for: bingos)
            table.append(Payout(bingos: bingos, win: win))
        }
        return table
    }
    
    func findBingoSpaces(for card: BingoCard) -> Set<BingoSpace> {
        let markedSpaces = card.markedSpaces // Only count spaces that were marked
        var bingoSpaces: Set<BingoSpace> = []

        // Check rows
        for row in 0..<card.rows {
            let rowSpaces = (0..<card.columns).map { card.spaces[row * card.columns + $0] }
            if rowSpaces.allSatisfy({ markedSpaces.contains($0) || $0.isFreeSpace }) {
                bingoSpaces.formUnion(rowSpaces)
            }
        }

        // Check columns
        for col in 0..<card.columns {
            let colSpaces = (0..<card.rows).map { card.spaces[$0 * card.columns + col] }
            if colSpaces.allSatisfy({ markedSpaces.contains($0) || $0.isFreeSpace }) {
                bingoSpaces.formUnion(colSpaces)
            }
        }

        // Check diagonal (top-left to bottom-right)
        let diagonal1Spaces = (0..<card.rows).map { card.spaces[$0 * card.columns + $0] }
        if diagonal1Spaces.allSatisfy({ markedSpaces.contains($0) || $0.isFreeSpace }) {
            bingoSpaces.formUnion(diagonal1Spaces)
        }

        // Check diagonal (top-right to bottom-left)
        let diagonal2Spaces = (0..<card.rows).map { card.spaces[$0 * card.columns + (card.columns - 1 - $0)] }
        if diagonal2Spaces.allSatisfy({ markedSpaces.contains($0) || $0.isFreeSpace }) {
            bingoSpaces.formUnion(diagonal2Spaces)
        }

        return bingoSpaces
    }
    
    // MARK: HELPERS
    
}

extension BingoViewModel {
    var bingoSpaceColor: Color {
        BingoColor(rawValue: bingoSpaceColorChoice)?.color ?? .yellow
    }
    
    var dauberColor: Color {
        BingoColor(rawValue: dauberColorChoice)?.color ?? .green
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
    case slow = 5.0
    case normal = 2.5
    case fast = 1.5
    case superFast = 0.75
    case lightening = 0.25

    var label: String {
        switch self {
        case .slow:        return "Slow"
        case .normal:      return "Normal"
        case .fast:        return "Fast"
        case .superFast:   return "Super Fast"
        case .lightening:  return "Lightening"
        }
    }

    var symbolName: String {
        switch self {
        case .slow:        return "tortoise"
        case .normal:      return "figure.walk"
        case .fast:        return "hare.fill"
        case .superFast:   return "flag.pattern.checkered"
        case .lightening:  return "bolt.fill"
        }
    }

    /// A custom color for the SF Symbol
    var symbolColor: Color {
        return .black
//        switch self {
//        case .slow:        return .green
//        case .normal:      return .blue
//        case .fast:        return .red
//        case .superFast:   return .orange
//        case .lightening:  return .yellow
//        }
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
