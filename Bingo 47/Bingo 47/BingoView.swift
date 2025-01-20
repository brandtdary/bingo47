//
//  BingoView.swift
//  Bingo Tap
//
//  Created by Brandt Dary on 1/15/25.
//

import SwiftUI
import GameKit

struct BingoView: View {
    @StateObject private var viewModel = BingoViewModel()

    @State private var showOutOfCredits = false
    @State private var showFavoritesSheet = false
    @State private var showGameCenter = false
    @State private var isAuthenticated = false

    // MARK: Ads
    @State private var isAdLoaded: Bool = false
    @State private var gamesPlayedThisSession: Int = 0

    @AppStorage("useBallIndicator") private var useBallIndicator: Bool = true
    
    var body: some View {
        GeometryReader { geometry in
            let safeAreaTop = geometry.safeAreaInsets.top
            let safeAreaBottom = geometry.safeAreaInsets.bottom
            let totalWidth = geometry.size.width * 0.95
            let totalHeight = geometry.size.height - (safeAreaTop + safeAreaBottom) // Adjust for safe area
            let cardSize = min(totalHeight * 0.35, 500) // Prioritize height, but limit to max 500px
            
            ZStack {
                // Background color
                Color.black
                    .ignoresSafeArea() // Extends to the edges of the screen
                
                VStack(spacing: 0) {
                    let heightOfHeader: CGFloat = 50

                    if gamesPlayedThisSession > 1 {
                        BannerAdView(isAdLoaded: $isAdLoaded)
                            .frame(height: heightOfHeader)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    } else {
                        // Title
                        Text("Bingo Tap")
                            .font(.largeTitle)
                            .bold()
                            .foregroundStyle(.white)
                            .frame(height: heightOfHeader)
                            .frame(maxWidth: .infinity)
                    }
                    
                    // Called Numbers Grid
                    BingoBoardView(calledSpaces: viewModel.calledSpaces, allSpaces: viewModel.allSpaces, totalWidth: totalWidth * 0.75, lastCalledNumber: viewModel.currentSpace)
                        .padding(.bottom, 8)
                    
                    ZStack {
                        VStack {
                            // MARK: Edit Cards
                            Button(action: {
                                showFavoritesSheet.toggle()
                            }) {
                                VStack(spacing: 0) {
                                    Image(systemName: "square.stack") // SF Symbol for refresh
                                        .font(.title)
                                        .foregroundColor(viewModel.isGameActive ? .yellow.opacity(0.25) : .yellow) // Disable when game is active
                                }
                                .padding(4)
                            }
                            .offset(x: viewModel.isGameActive ? 0 : (cardSize / 2) + 35)
                            .animation(.spring, value: viewModel.isGameActive)
                            .disabled(viewModel.isGameActive) // Prevent changing during an active game
                        }
                        
                        // MARK: Bingo Card
                        ZStack {
                            ForEach(viewModel.bingoCards) { card in
                                let bingoSpaces = viewModel.findBingoSpaces(for: card)
                                BingoCardView(
                                    bingoCard: card,
                                    calledSpaces: viewModel.calledSpaces,
                                    bingoSpaces: bingoSpaces,
                                    viewModel: viewModel,
                                    markSpace: { space, card in
                                        if !viewModel.autoMark {
                                            viewModel.markSpace(space, cardID: card.id)
                                        }
                                    },
                                    cardSize: cardSize // Pass computed size
                                )
                            }
                            
                            Text("Gud Milk").font(.system(size: cardSize / 30))
                                .offset(y: (cardSize / 10))
                                .foregroundStyle(viewModel.isGameActive ? .clear : .white)
                        }
                    }
                    
                    if viewModel.isLastCallActive {
                        HStack(spacing: 4) {
                            Text("Last Call!")
                                .font(.subheadline)
                                .bold()
                                .foregroundColor(.yellow)
                            
                            Text("(\(viewModel.lastCallSecondsRemaining)s)")
                                .font(.subheadline)
                                .foregroundColor(.yellow.opacity(0.75))
                        }
                    } else {
                        
                        VStack(alignment: .trailing, spacing: 0) {
                            let ballSize = (geometry.size.width * 0.9) / CGFloat(viewModel.numbersToDraw)
                            if useBallIndicator {
                                // Ball Indicator View
                                HStack(spacing: 1) {
                                    ForEach(0..<(viewModel.numbersToDraw - viewModel.calledSpaces.count), id: \.self) { index in
                                        Circle()
                                            .fill(Color.white)
                                            .frame(width: ballSize, height: ballSize)
                                    }
                                    Spacer()
                                }
                                .frame(height: ballSize * 1.1)
                                .clipShape(Rectangle())
                                .onTapGesture(count: 2) {
                                    useBallIndicator.toggle()
                                }
                            } else {
                                // Text Counter View
                                HStack {
                                    Text("#s Left:")
                                        .font(.subheadline)
                                        .foregroundStyle(Color.white)
                                    Text("\(viewModel.numbersToDraw - viewModel.calledSpaces.count)")
                                        .font(.subheadline)
                                        .foregroundStyle(Color.white)
                                }
                                .frame(height: 20)
                                .opacity(viewModel.isGameActive ? 1 : 0)
                                .animation(.default, value: viewModel.isGameActive)
                                .onTapGesture(count: 2) {
                                    useBallIndicator.toggle()
                                }
                            }
                        }                    }
                    
                    HStack(alignment: .top) {
                        let payoutTableWidth = min(300, totalWidth * 0.4) // Expands on iPads, but maxes at 300px
                        let payoutTableHeight = totalHeight * 0.35
                        
                        // MARK:  Payout Table - Dynamically sized
                        VStack(spacing: 0) {
                            ZStack {
                                Text("Bingos Win")
                                    .font(.system(size: payoutTableHeight * 0.09, weight: .bold))
                                    .opacity(0) // Hidden reference text
                                
                                HStack {
                                    Text("Bingos")
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.1)
                                    Spacer()
                                    Text("Win")
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.1)
                                }
                                .font(.system(size: payoutTableHeight * 0.09, weight: .bold))
                            }
                            .frame(maxWidth: .infinity)
                            .foregroundColor(.white)
                            .padding(.horizontal)
                            .padding(.top, 8)

                            ForEach(viewModel.payoutTable, id: \.bingos) { payout in
                                let isHighlighted = payout.win == viewModel.currentGameWinnings
                                HStack {
                                    Text("\(payout.bingos)")
                                        .font(.system(size: payoutTableHeight * 0.06, weight: .bold))
                                        .minimumScaleFactor(0.5)
                                    Spacer()
                                    Text("\(payout.win)")
                                        .font(.system(size: payoutTableHeight * 0.06, weight: .bold))
                                        .minimumScaleFactor(0.5)
                                }
                                .frame(maxWidth: .infinity, minHeight: payoutTableHeight * 0.06)
                                .padding(.horizontal)
                                .background(isHighlighted ? Color.yellow : Color.clear)
                                .foregroundColor(isHighlighted ? .red : .white)
                            }
                            Spacer()
                        }
                        .frame(width: payoutTableWidth)
                        .frame(maxHeight: .infinity)
                        .background(Color.blue.opacity(0.75))
                        .cornerRadius(15) // Ensures the container has rounded corners
                        .overlay( // Adds a border with rounded corners
                            RoundedRectangle(cornerRadius: 15) // Same corner radius as background
                                .inset(by: 2) // Moves the border fully inside by 2 points
                                .stroke(Color.yellow, lineWidth: 2) // 2-pixel-thick yellow border
                        )
                        
                        VStack(alignment: .trailing, spacing: 0) {
                            HStack {
                                // New Buy Credits Button
                                Button(action: {
                                    showStore()
                                }) {
                                    Text("BUY")
                                        .font(.subheadline).bold()
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.1)
                                        .padding(12)
                                        .background(viewModel.isGameActive ? .red.opacity(0.25) : .red)
                                        .cornerRadius(15)
                                        .frame(maxHeight: 44)
                                }
                                .disabled(viewModel.isGameActive)
                                
                                if isAuthenticated {
                                    Button(action: {
                                        showGameCenter = true
                                    }) {
                                        Image(systemName: "list.bullet.circle.fill")
                                            .font(.largeTitle)
                                            .foregroundStyle(.green)
                                    }
                                    .padding(.leading, 12)
                                }
                                
                                Spacer()

                                
                                // MARK: SETTINGS MENU
                                Menu {
                                    // AutoMark Toggle
                                    Button(action: {
                                        viewModel.autoMark.toggle()
                                        HapticManager.shared.triggerHaptic(for: .choose)
                                    }) {
                                        HStack {
                                            Text("Auto-Mark")
                                            Spacer()
                                            if viewModel.autoMark {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                    
                                    // AutoMark Toggle
                                    Button(action: {
                                        viewModel.vibrationEnabled.toggle()
                                    }) {
                                        HStack {
                                            Text("Vibration")
                                            Spacer()
                                            if viewModel.vibrationEnabled {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }

                                    
                                    // Speak Numbers Toggle
                                    Button(action: {
                                        viewModel.speakSpaces.toggle()
                                        HapticManager.shared.triggerHaptic(for: .choose)
                                    }) {
                                        HStack {
                                            Text("Speak Numbers")
                                            Spacer()
                                            if viewModel.speakSpaces {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                    
                                    Menu("Game Speed") {
                                        ForEach(GameSpeedOption.allCases, id: \.self) { speed in
                                            Button {
                                                viewModel.gameSpeed = speed
                                                HapticManager.shared.triggerHaptic(for: .choose)
                                            } label: {
                                                HStack(spacing: 8) {
                                                    Label(speed.label, systemImage: speed.symbolName)
                                                        .symbolRenderingMode(.palette)
                                                        .foregroundStyle(speed.symbolColor, .gray)
                                                    
                                                    Spacer()
                                                    
                                                    // Checkmark if this speed is selected
                                                    if viewModel.gameSpeed == speed {
                                                        Image(systemName: "checkmark")
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    
                                    Menu("Bingo Space Color") {
                                            ForEach(BingoColor.allCases) { colorOption in
                                                Button {
                                                    viewModel.bingoSpaceColorChoice = colorOption.rawValue
                                                } label: {
                                                    Label(colorOption.rawValue.capitalized, systemImage: colorOption == .random ? "shuffle.circle.fill" : "circle.fill")
                                                        .symbolRenderingMode(.palette)
                                                        .foregroundStyle(colorOption.color, .white)
                                                }
                                            }
                                        }
                                        
                                        // Another sub-menu for “Dauber Color”:
                                        Menu("Dauber Color") {
                                            ForEach(BingoColor.allCases) { colorOption in
                                                Button {
                                                    viewModel.dauberColorChoice = colorOption.rawValue
                                                } label: {
                                                    Label(colorOption.rawValue.capitalized, systemImage: colorOption == .random ? "shuffle.circle.fill" : "circle.fill")
                                                        .symbolRenderingMode(.palette)
                                                        .foregroundStyle(colorOption.color, .white)
                                                }
                                            }
                                        }
                                    
                                } label: {
                                    Image(systemName: "slider.horizontal.3") // SF Symbol for settings
                                        .font(.largeTitle)
                                        .foregroundColor(viewModel.isGameActive ? .yellow.opacity(0.25) : .yellow)
                                }
                            }
                            .disabled(viewModel.isGameActive)
                            
                            Spacer()
                            
                            HStack {
                                HStack(spacing: 8) {
                                    Image(systemName: "47.circle.fill") // SF Symbol for money
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 24, height: 24)
                                        .foregroundColor(.green) // Highlighting it in gold/yellow
                                    
                                    Text("\(viewModel.jackpotStorage[viewModel.betMultiplier, default: 0]) x $47")
                                        .font(.headline)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.25)
                                        .foregroundColor(.white)
                                }
                                
                                Spacer()
                                                                
                                VStack(alignment: .trailing, spacing: 0) {
                                    Text("\(viewModel.credits)")
                                        .font(.title).bold()
                                        .minimumScaleFactor(0.15)
                                        .foregroundStyle(Color.white)
                                        .onLongPressGesture(minimumDuration: 0.75) {
                                            viewModel.resetCredits()
                                        }
                                    Text("Credits")
                                        .font(.title3)
                                        .minimumScaleFactor(0.15)
                                        .foregroundStyle(Color.white)
                                }
                                .padding(.leading, 12) // Ensures spacing on smaller screens
                            }

                            Spacer()
                            
                            HStack(spacing: 12) {
                                VStack(spacing: 8) {
                                    Button(action: {
                                        viewModel.toggleBetMultiplier()
                                    }) {
                                        Text("BET: \(viewModel.betMultiplier * viewModel.baseBet)")
                                            .font(.headline)
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.1)
                                    }
                                    .buttonStyle(BingoButtonStyle(backgroundColor: .red, textColor: .white, height: 44, isDisabled: viewModel.isGameActive))
                                    .disabled(viewModel.isGameActive)

                                    Button(action: {
                                        if viewModel.currentBet > viewModel.credits {
                                            showStore()
                                        } else {
                                            gamesPlayedThisSession += 1
                                            viewModel.beginGame()
                                        }
                                    }) {
                                        Text("PLAY")
                                            .font(.title)
                                            .bold()
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.1)
                                    }
                                    .buttonStyle(BingoButtonStyle(backgroundColor: .red, textColor: .white, height: 55, isDisabled: viewModel.isGameActive))
                                    .disabled(viewModel.isGameActive)
                                }
                            }
                            .frame(maxWidth: 400) // Prevents excessive width on larger screens
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, safeAreaBottom)
                }
                
                // Keep the overlay in the hierarchy at all times
                OutOfCreditsView(allowClose: viewModel.credits > viewModel.baseBet, isVisible: $showOutOfCredits, viewModel: viewModel)
            }
            .sheet(isPresented: $showFavoritesSheet) {
                CardChooserView(viewModel: viewModel)
            }
            .sheet(isPresented: $showGameCenter) {
                GameCenterView(viewState: .leaderboards) {
                    showGameCenter = false
                }
            }
            .sheet(isPresented: $viewModel.showJackpotSheet) {
                VStack(spacing: 20) {
                    Text("🎉 Jackpot Received! 🎉")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("You won \(viewModel.lastJackpotCount) x $47 bills.")
                        .font(.title2)

                    Text("Total Winnings: \(viewModel.lastJackpotAmount) credits")
                        .font(.title)
                        .foregroundColor(.green)

                    Button("COLLECT") {
                        viewModel.showJackpotSheet = false
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                }
                .padding()
            }
            .onAppear {
                authenticateUser()
            }
        }
    }
    
    private func showStore() {
        showOutOfCredits = true
    }
    
    func authenticateUser() {
            let localPlayer = GKLocalPlayer.local
            localPlayer.authenticateHandler = { viewController, error in
                if let viewController = viewController {
                    // Present the Game Center login view controller
                    if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                        scene.windows.first?.rootViewController?.present(viewController, animated: true)
                    }
                } else if localPlayer.isAuthenticated {
                    isAuthenticated = true
                    // Enable Game Center features
                } else {
                    // Handle authentication failure
                    isAuthenticated = false
                }
            }
        }
}

struct BingoButtonStyle: ButtonStyle {
    var backgroundColor: Color
    var textColor: Color
    var height: CGFloat // Pass in desired height
    var isDisabled: Bool = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(maxWidth: .infinity, minHeight: height, maxHeight: height) // Ensures height constraint
            .padding(.horizontal, 16)
            .background(isDisabled ? backgroundColor.opacity(0.25) : backgroundColor)
            .foregroundColor(textColor)
            .cornerRadius(15)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0) // Slight press animation
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}

struct BingoBoardView: View {
    let calledSpaces: Set<BingoSpace>
    let allSpaces: [BingoSpace]
    let totalWidth: CGFloat // Passed from parent
    let lastCalledNumber: BingoSpace? // Last called number
    
    var body: some View {
        let columns = 6
        let spacing: CGFloat = 0 // Ensure no gaps
        let columnWidth = (totalWidth - (spacing * CGFloat(columns - 1))) / CGFloat(columns) * 0.8
        let borderWidth = max(1, columnWidth * 0.05) // Adjust border based on column width
        
        LazyVGrid(
            columns: Array(repeating: GridItem(.fixed(columnWidth), spacing: spacing), count: columns),
            spacing: spacing // No gaps between rows
        ) {
            ForEach(allSpaces, id: \.id) { space in
                let isLastCalled = space == lastCalledNumber
                let isCalled = calledSpaces.contains(space)

                ZStack {
                    Rectangle()
                        .fill(isLastCalled ? .yellow : isCalled ? Color.red : Color.blue)
                        .aspectRatio(1, contentMode: .fit)
                        .border(Color.white, width: borderWidth) // Dynamically sized border
                    
                    if isCalled {
                        Image(systemName: "star.fill")
                            .font(.system(size: columnWidth * 0.55, weight: .bold)) // Scale text
                            .lineLimit(1) // Prevent multi-line wrapping
                            .minimumScaleFactor(0.5) // Shrink text instead of wrapping
                            .foregroundColor(.white)
                            .shadow(color: isLastCalled ? .clear : .black, radius: 0.5, x: 1, y: 1)
                    } else {
                        Text(space.label)
                            .font(.system(size: columnWidth * 0.55, weight: .bold)) // Scale text
                            .lineLimit(1) // Prevent multi-line wrapping
                            .minimumScaleFactor(0.5) // Shrink text instead of wrapping
                            .foregroundColor(.white)
                            .shadow(color: isLastCalled ? .clear : .black, radius: 0.5, x: 1, y: 1)
                    }
                }
            }
        }
        .frame(width: totalWidth) // Ensure grid spans full width
    }
}

struct BingoCardView: View {
    let bingoCard: BingoCard
    let calledSpaces: Set<BingoSpace>
    let bingoSpaces: Set<BingoSpace>
    let viewModel: BingoViewModel
    
    // markSpace closure, optionally nil
    let markSpace: ((BingoSpace, BingoCard) -> Void)?
    
    let cardSize: CGFloat
    
    init(
        bingoCard: BingoCard,
        calledSpaces: Set<BingoSpace>,
        bingoSpaces: Set<BingoSpace>,
        viewModel: BingoViewModel,
        markSpace: ((BingoSpace, BingoCard) -> Void)? = nil,
        cardSize: CGFloat
    ) {
        self.bingoCard = bingoCard
        self.calledSpaces = calledSpaces
        self.bingoSpaces = bingoSpaces
        self.viewModel = viewModel
        self.markSpace = markSpace
        self.cardSize = cardSize
    }

    var body: some View {
        let cellSize = cardSize / CGFloat(bingoCard.columns)
        
        VStack(spacing: 0) {
            ForEach(0..<bingoCard.rows, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<bingoCard.columns, id: \.self) { column in
                        let spaceIndex = (column * bingoCard.rows) + row
                        if spaceIndex < bingoCard.spaces.count {
                            let space = bingoCard.spaces[spaceIndex]
                            let isMarked = bingoCard.markedSpaces.contains(space)
                            let isPartOfBingo = isMarked && viewModel.isPartOfBingo(space, for: bingoCard)
                            
                            BingoSpaceView(
                                space: space,
                                isCalled: calledSpaces.contains(space),
                                isMarked: isMarked,
                                isPartOfBingo: isPartOfBingo,
                                spaceSize: cellSize,
                                isLastCallActive: viewModel.isLastCallActive,
                                highlightColor: viewModel.activeBingoSpaceColor,
                                dauberColor: viewModel.activeDauberColor,
                                
                                onTap: { tappedSpace in
                                    markSpace?(tappedSpace, bingoCard)
                                }
                            )
                            .frame(width: cellSize, height: cellSize)
                        }
                    }
                }
            }
        }
        .frame(width: cardSize, height: cardSize)
        .background(Color.blue)
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .stroke(Color.gray, lineWidth: 3)
        )
        .padding(2)
    }
}

struct BingoSpaceView: View {
    let space: BingoSpace
    let isCalled: Bool
    let isMarked: Bool
    let isPartOfBingo: Bool
    let spaceSize: CGFloat
    let isLastCallActive: Bool

    let highlightColor: Color
    let dauberColor: Color

    let onTap: (BingoSpace) -> Void

    var body: some View {
        ZStack {
            Rectangle()
                .fill(isPartOfBingo ? highlightColor : .white.opacity(0.25))
                .overlay(
                    Rectangle()
                        .stroke(Color.black.opacity(0.75), lineWidth: 1)
                )
            
            if isMarked {
                Circle()
                    .fill(dauberColor)
                    .frame(width: spaceSize * 0.9, height: spaceSize * 0.9)
            } else {
                if isLastCallActive && isCalled {
                    Circle()
                        .stroke(
                            dauberColor,
                            style: StrokeStyle(lineWidth: 3, dash: [4, 4])
                        )
                        .frame(width: spaceSize * 0.9, height: spaceSize * 0.9)
                }
            }
            let fontSize = space.isFreeSpace ? spaceSize * 0.3 : space.id == BingoViewModel.bonusSpaceID ? spaceSize * 0.5 : spaceSize * 0.4

            Text(space.label)
                .font(.system(size: fontSize, weight: .bold))
                .padding(space.isFreeSpace ? 2 : 0)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .foregroundColor(space.isFreeSpace ? .white : .white)
        }
        .frame(width: spaceSize, height: spaceSize)
        .onTapGesture {
            onTap(space)
        }
    }
}


enum BingoColor: String, CaseIterable, Identifiable {
    case random
    case red, orange, yellow, green, blue, purple, pink, brown, black
    // (Removed .white, .rainbow)

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .red:      return .red
        case .orange:   return .orange
        case .yellow:   return .yellow
        case .green:    return .green
        case .blue:     return .blue
        case .purple:   return .purple
        case .pink:     return .pink
        case .brown:    return .brown
        case .black:    return .black
            
        case .random:
            // Just return black by default (or any fallback) if code calls this directly.
            // The real random picking is done in the ViewModel.
            return .black
        }
    }
}

// MARK: Game Center Views

struct GameCenterView: UIViewControllerRepresentable {
    let viewState: GKGameCenterViewControllerState
    let dismissAction: () -> Void

    func makeUIViewController(context: Context) -> GKGameCenterViewController {
        let gameCenterVC = GKGameCenterViewController()
        gameCenterVC.gameCenterDelegate = context.coordinator
        gameCenterVC.viewState = viewState
        return gameCenterVC
    }

    func updateUIViewController(_ uiViewController: GKGameCenterViewController, context: Context) {
        // No update code needed
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(dismissAction: dismissAction)
    }

    class Coordinator: NSObject, GKGameCenterControllerDelegate {
        let dismissAction: () -> Void

        init(dismissAction: @escaping () -> Void) {
            self.dismissAction = dismissAction
        }

        func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
            dismissAction()
        }
    }
}
