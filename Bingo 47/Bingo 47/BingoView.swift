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
    @State private var showSettingsMenu = false
    @State private var isCopied = false

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
            let cardSize = min(totalHeight * 0.30, 500) // Prioritize height, but limit to max 500px
            
            ZStack {
                // Background color
                Color.black
                    .ignoresSafeArea() // Extends to the edges of the screen
                
                VStack(spacing: 0) {
                    let heightOfHeader: CGFloat = 50

                    VStack {
                        if gamesPlayedThisSession > 1 {
                            BannerAdView(isAdLoaded: $isAdLoaded)
                                .frame(height: heightOfHeader)
                                .transition(.move(edge: .top).combined(with: .opacity))
                        } else {
                            // Title
                            Image("logo")
                                .resizable()
                                .scaledToFit()
                                .frame(height: heightOfHeader)
                        }
                    }
                    .padding(.bottom, 4)
                    
                    // Called Numbers Grid
                    BingoBoardView(calledSpaces: viewModel.calledSpaces, allSpaces: viewModel.allSpaces, totalWidth: totalWidth * 0.65, lastCalledNumber: viewModel.currentSpace)
                        .padding(.bottom, 8)
                    
                    ZStack {
                        VStack(spacing: 0) {
                                Image("47bill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxWidth: cardSize / 3.5)

                                // Single Jackpot Counter
                                Text("x \(viewModel.animatedJackpotCount.formatted(shortened: true))")
                                    .font(.system(size: cardSize / 11)).bold()
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.25)
                                    .foregroundColor(.white)
                            }
                            .offset(x: viewModel.shouldShowJackpotDisplay() ? -((cardSize / 2) + 55) : 0)
                            .animation(.spring, value: viewModel.shouldShowJackpotDisplay())
                        
                        
                        VStack(spacing: 16) {
                            // MARK: SETTINGS MENU
//                            Menu {
//                                // AutoMark Toggle
//                                // Auto-Mark Toggle
//                                Button(action: {
//                                    viewModel.autoMark.toggle()
//                                    HapticManager.shared.triggerHaptic(for: .choose)
//                                }) {
//                                    let emoji = viewModel.autoMark ? "🟩" : "⬜️"
//                                    Label("\(emoji) Auto-Mark", systemImage: "checkmark.square")
//                                }
//                                
//                                // Vibration Toggle
//                                Button(action: {
//                                    viewModel.vibrationEnabled.toggle()
//                                }) {
//                                    let emoji = viewModel.vibrationEnabled ? "🟩" : "⬜️"
//                                    Label("\(emoji) Vibration", systemImage: "iphone.radiowaves.left.and.right")
//                                }
//                                
//                                // Speak Numbers Toggle
//                                Button(action: {
//                                    viewModel.speakSpaces.toggle()
//                                    HapticManager.shared.triggerHaptic(for: .choose)
//                                }) {
//                                    let emoji = viewModel.speakSpaces ? "🟩" : "⬜️"
//                                    Label("\(emoji) Speak Numbers", systemImage: "speaker.wave.3.fill")
//                                }
//
//                                Menu("Game Speed") {
//                                    ForEach(GameSpeedOption.allCases, id: \.self) { speed in
//                                        Button {
//                                            viewModel.gameSpeed = speed
//                                            HapticManager.shared.triggerHaptic(for: .choose)
//                                        } label: {
//                                            HStack(spacing: 8) {
////                                                if viewModel.gameSpeed == speed {
////                                                    Image(systemName: "checkmark")
////                                                        .foregroundStyle(speed.symbolColor, .gray)
////                                                }
//                                                
//                                                let text = viewModel.gameSpeed == speed ? "🟩 " : "⬜️ "
//                                                
//                                                let color = viewModel.gameSpeed == speed ? Color.red : .secondary
//                                                Label(text + speed.label, systemImage: speed.symbolName)
//                                                    .symbolRenderingMode(.palette)
//                                                    .foregroundStyle(speed.symbolColor, color)
//                                                
////                                                Spacer()
////
////                                                // Checkmark if this speed is selected
////                                                if viewModel.gameSpeed == speed {
////                                                    Image(systemName: "checkmark")
////                                                        .foregroundStyle(speed.symbolColor, .gray)
////                                                }
//                                            }
//                                        }
//                                    }
//                                }
//                                
//                                
//                                
//                                // Not this time... we like the colors WE chose.
//                                //                                Menu("Bingo Space Color") {
//                                //                                        ForEach(BingoColor.allCases) { colorOption in
//                                //                                            Button {
//                                //                                                viewModel.bingoSpaceColorChoice = colorOption.rawValue
//                                //                                            } label: {
//                                //                                                Label(colorOption.rawValue.capitalized, systemImage: colorOption == .random ? "shuffle.circle.fill" : "circle.fill")
//                                //                                                    .symbolRenderingMode(.palette)
//                                //                                                    .foregroundStyle(colorOption.color, .white)
//                                //                                            }
//                                //                                        }
//                                //                                    }
//                                //
//                                //                                    // Another sub-menu for “Dauber Color”:
//                                //                                    Menu("Dauber Color") {
//                                //                                        ForEach(BingoColor.allCases) { colorOption in
//                                //                                            Button {
//                                //                                                viewModel.dauberColorChoice = colorOption.rawValue
//                                //                                            } label: {
//                                //                                                Label(colorOption.rawValue.capitalized, systemImage: colorOption == .random ? "shuffle.circle.fill" : "circle.fill")
//                                //                                                    .symbolRenderingMode(.palette)
//                                //                                                    .foregroundStyle(colorOption.color, .white)
//                                //                                            }
//                                //                                        }
//                                //                                    }
//                                
//                            } label: {
//                                Image(systemName: "slider.horizontal.3") // SF Symbol for settings
//                                    .font(.largeTitle)
//                                    .foregroundColor(.yellow.dimmedIf(viewModel.isGameActive))
//                            }
//                            .disabled(viewModel.isGameActive)


                            Button {
                                showSettingsMenu.toggle()
                            } label: {
                                Image(systemName: "slider.horizontal.3")
                                    .font(.largeTitle)
                                    .foregroundColor(.yellow.dimmedIf(viewModel.isGameActive))
                            }
                            .sheet(isPresented: $showSettingsMenu) {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Game Settings")
                                        .font(.title)
                                        .bold()
                                        .padding(.bottom, 8)

                                    // Auto-Mark Toggle
                                    Toggle(isOn: $viewModel.autoMark) {
                                        Label {
                                            Text("Auto-Mark")
                                        } icon: {
                                            Image(systemName: "checkmark.circle")
                                                .frame(width: 48, alignment: .center)
                                        }
                                    }
                                    .toggleStyle(SwitchToggleStyle())

                                    // Vibration Toggle
                                    Toggle(isOn: $viewModel.vibrationEnabled) {
                                        Label {
                                            Text("Vibration")
                                        } icon: {
                                            Image(systemName: "iphone.radiowaves.left.and.right.circle")
                                                .frame(width: 48, alignment: .center)
                                        }
                                    }
                                    .toggleStyle(SwitchToggleStyle())

                                    // Speak Numbers Toggle
                                    Toggle(isOn: $viewModel.speakSpaces) {
                                        Label {
                                            Text("Speak Numbers")
                                        } icon: {
                                            Image(systemName: "speaker.wave.2.circle")
                                                .frame(width: 48, alignment: .center)
                                        }
                                    }
                                    .toggleStyle(SwitchToggleStyle())
                                    .disabled(viewModel.gameSpeed == .fast || viewModel.gameSpeed == .lightening)
                                    
                                    Text("Speaking numbers requires that you be playing on **Slow** or **Normal** speed.")
                                        .font(.footnote)
                                        .padding(.leading, 56)
                                        .padding(.bottom, 16)

                                    // Game Speed Selection
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Game Speed")
                                            .font(.headline)
                                            .bold()

                                        Picker("Game Speed", selection: $viewModel.gameSpeed) {
                                            ForEach(GameSpeedOption.allCases, id: \.self) { speed in
                                                Text(speed.label).tag(speed)
                                            }
                                        }
                                        .pickerStyle(.segmented)
                                        .padding(.vertical, 8)
                                    }
                                    
                                    Spacer()

                                    VStack(alignment: .center, spacing: 24) {
                                        Button("RETURN TO GAME") {
                                            showSettingsMenu = false
                                        }
                                        .font(.title3).bold()
                                        .foregroundColor(.yellow)
                                        
                                        Button("MORE FUN GAMES") {
                                            if let url = URL(string: "https://gudmilk.com") {
                                                UIApplication.shared.open(url)
                                            }
                                        }
                                        .font(.title3).bold()
                                        .foregroundColor(.yellow)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    
                                    
                                    Section(header: Text("Support").font(.headline).foregroundColor(.white)) {
                                        // Website Link
                                        Text("GudMilk.com")
                                            .font(.headline)
                                            .foregroundColor(.blue)
                                            .onTapGesture {
                                                if let url = URL(string: "https://gudmilk.com") {
                                                    UIApplication.shared.open(url)
                                                }
                                            }
                                        
                                        // Email Support with Copy Option
                                        HStack(spacing: 8) {
                                            let supportEmail = "support@gudmilk.com"
                                            
                                            // Email Address (opens default email client)
                                            Text(supportEmail)
                                                .font(.body)
                                                .foregroundColor(.blue)
                                                .onTapGesture {
                                                    let subject = "Bingo 47 Support"
                                                    let emailURL = "mailto:\(supportEmail)?subject=\(subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
                                                    if let url = URL(string: emailURL) {
                                                        UIApplication.shared.open(url)
                                                    }
                                                }
                                            
                                            // Copy to Clipboard Icon
                                            Image(systemName: "doc.on.doc") // Clipboard icon
                                                .foregroundColor(.blue)
                                                .onTapGesture {
                                                    HapticManager.shared.triggerHaptic(for: .choose)
                                                    UIPasteboard.general.string = supportEmail
                                                    isCopied = true
                                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                                        isCopied = false
                                                    }
                                                }
                                            
                                            // Copied Feedback
                                            if isCopied {
                                                Text("Copied!")
                                                    .font(.footnote)
                                                    .foregroundColor(.green)
                                                    .transition(.opacity)
                                            }
                                        }
                                    }
                                    
                                    // MARK: App Info
                                    VStack(alignment: .center, spacing: 4) {
                                        Text("© 2025 Gud Milk")
                                            .font(.footnote)
                                            .foregroundColor(.gray)
                                        
                                        if let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
                                           let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                                            Text("Version \(appVersion) (\(buildNumber))")
                                                .font(.footnote)
                                                .foregroundColor(.gray)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding()
                                }
                                .padding()
                                .presentationDragIndicator(.visible) // Shows a grabber at the top
                            }
                            
                            // MARK: Edit Cards
                            Button(action: {
                                showFavoritesSheet.toggle()
                            }) {
                                VStack(spacing: 0) {
                                    Image(systemName: "square.stack") // SF Symbol for refresh
                                        .font(.title)
                                        .foregroundColor(.yellow.dimmedIf(viewModel.isGameActive))
                                }
                                .padding(4)
                            }
                            .disabled(viewModel.isGameActive) // Prevent changing during an active game
                        }
                        .offset(x: viewModel.isGameActive ? 0 : (cardSize / 2) + 35)
                        .animation(.spring, value: viewModel.isGameActive)
                        
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
                                .offset(y: (cardSize / 9))
                                .foregroundStyle(viewModel.isGameActive ? .clear : .white)
                        }
                    }
                    
                    let sectionHeight = geometry.size.width * 0.9 / CGFloat(viewModel.defaultNumbersToDraw)
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
                        .frame(height: sectionHeight)

                    } else {
                        let ballSize = (geometry.size.width * 0.9) / CGFloat(viewModel.numbersToDraw)
                        VStack(alignment: .trailing, spacing: 0) {
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
                                .frame(height: sectionHeight)
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
                                .frame(height: sectionHeight)
                                .opacity(viewModel.isGameActive ? 1 : 0)
                                .animation(.default, value: viewModel.isGameActive)
                                .onTapGesture(count: 2) {
                                    useBallIndicator.toggle()
                                }
                            }
                        }
                    }
                    
                    HStack(alignment: .top) {
                        let payoutTableWidth = min(300, totalWidth * 0.4) // Expands on iPads, but maxes at 300px
                        let payoutTableHeight = totalHeight * 0.35
                        
                        // MARK:  Payout Table - Dynamically sized
                        VStack(alignment: .center, spacing: 0) {
                            VStack(spacing: 0) {
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
                                .frame(maxWidth: .infinity)
                                .foregroundColor(.white)
                                .padding(.horizontal)
                                .padding(.top, 4)
                                
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
//                            .frame(width: payoutTableWidth)
                            .background(Color.blue.opacity(0.75))
                            .cornerRadius(15) // Ensures the container has rounded corners
                            .overlay( // Adds a border with rounded corners
                                RoundedRectangle(cornerRadius: 15) // Same corner radius as background
                                    .inset(by: 2) // Moves the border fully inside by 2 points
                                    .stroke(Color.yellow, lineWidth: 2) // 2-pixel-thick yellow border
                            )
                                                        
                            Button(action: {
                                showGameCenter = true
                            }) {
                                Text("LEADERBOARDS")
                                    .font(.subheadline)
                                    .padding(12)
                                    .foregroundColor(.white.dimmedIf(viewModel.isGameActive))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.1)
                                    .background(.purple.dimmedIf(viewModel.isGameActive))
                                    .cornerRadius(15)
                                    .frame(maxHeight: 40)
                                    .frame(maxWidth: .infinity)
                                    .opacity(isAuthenticated ? 1 : 0)
                                    .padding(.top, 4)
                                
                            }
                            .disabled(!isAuthenticated || viewModel.isGameActive)
                        }
                        
                        VStack(alignment: .trailing, spacing: 0) {
                            HStack(spacing: 8) {
                                // Video Bonus Button
                                Button(action: {
                                    viewModel.tryShowingRewardedAd()
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "play.rectangle.fill")
                                            .font(.system(size: 18)) // Fixed size but still scales
                                            .layoutPriority(1)
                                        
                                        Text("+\(viewModel.bonusBallsOffer ?? 0)")
                                            .bold()
                                            .font(.system(size: 16)) // Allows shrinkage but remains readable
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.5) // Ensures it scales but stays on one line
                                            .layoutPriority(1)
                                        
                                        Image(systemName: "circle.fill")
                                            .font(.system(size: 14)) // Slightly smaller than text to prevent clipping
                                            .foregroundColor(.white.dimmedIf(viewModel.isGameActive))
                                            .layoutPriority(1)
                                    }
                                    .foregroundColor(.black)
                                    .padding(8)
                                    .frame(maxWidth: 300)
                                    .frame(height: 44)
                                    .background(Color.gold.dimmedIf(viewModel.isGameActive))
                                    .cornerRadius(15)
                                    .scaleEffect(viewModel.bonusBallsOffer != nil ? 1.0 : 0.25)
                                    .opacity(viewModel.bonusBallsOffer != nil ? 1 : 0)
                                    .animation(.spring(response: 0.4, dampingFraction: 0.6, blendDuration: 0), value: viewModel.bonusBallsOffer)
                                }
                                .disabled(viewModel.isGameActive)

                                // SHOP Button
                                Button(action: {
                                    showStore()
                                }) {
                                    Text("SHOP")
                                        .font(.subheadline).bold()
                                        .foregroundColor(.black)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.1)
                                        .padding(8)
                                        .frame(width: 80, height: 44) // Fixed width and height for consistency
                                        .background(Color.gold.dimmedIf(viewModel.isGameActive))
                                        .cornerRadius(15)
                                }
                                .disabled(viewModel.isGameActive)
                            }
                            .frame(maxWidth: .infinity)
                            
                            Spacer()
                            
                            HStack {
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
                                        HStack(spacing: 0) {
                                            Text("PLAY")
                                                .font(.title)
                                                .bold()
                                                .lineLimit(1)
                                                .minimumScaleFactor(0.1)
                                                .layoutPriority(1)
                                            
                                            if viewModel.bonusBalls > 0 {
                                                Text(" +\(viewModel.bonusBalls) ")
                                                    .font(.subheadline)
                                                    .lineLimit(1)
                                                    .minimumScaleFactor(0.1)
                                                    .layoutPriority(1)
                                                Image(systemName: "circle.fill")
                                                    .font(.system(size: 16))
                                                    .lineLimit(1)
                                                    .minimumScaleFactor(0.1)
                                                    .foregroundStyle(Color.white)
                                            }
                                        }
                                        .animation(.spring(response: 0.6, dampingFraction: 0.6, blendDuration: 0), value: viewModel.bonusBalls)
                                        

                                    }
                                    .buttonStyle(BingoButtonStyle(backgroundColor: .red, textColor: .white, height: 75, isDisabled: viewModel.isGameActive))
                                    .disabled(viewModel.isGameActive)
                                }
                            }
                            .frame(maxWidth: 400) // Prevents excessive width on larger screens
                        }
                    }
                    .padding(.top, 4)
                    .padding(.bottom, safeAreaBottom)
                }
                
                // Keep the overlay in the hierarchy at all times
                let showLowerBetButton =  viewModel.credits >= viewModel.baseBet && viewModel.credits < (viewModel.baseBet * viewModel.betMultiplier)
                let allowClose = viewModel.credits > viewModel.baseBet
                OutOfCreditsView(showCloseButton: allowClose, showLowerBetButton: showLowerBetButton, isVisible: $showOutOfCredits, viewModel: viewModel)
            }
            
#if DEBUG
            // Error Messages Overlay
            ScrollView {
                VStack(alignment: .center) {
                    ForEach(viewModel.errorMessages.indices, id: \.self) { index in
                        Text(viewModel.errorMessages[index])
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.red.opacity(0.95))
                            .foregroundColor(.white)
                            .cornerRadius(10)
                            .transition(.opacity)
                            .onTapGesture {
                                viewModel.dismissError(at: index)
                            }
                    }
                    
                    Button {
                        viewModel.errorMessages.removeAll()
                    } label: {
                        Text("Clear All")
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.blue)
                            .foregroundStyle(.white)
                            .cornerRadius(10)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
            }
            .frame(maxHeight: viewModel.errorMessages.isEmpty ? 0 : .infinity) // Prevent it from taking too much space
            .animation(.easeInOut, value: viewModel.errorMessages)
#endif
            
        }
        .onAppear {
            authenticateUser()
        }

        .sheet(isPresented: $showFavoritesSheet) {
            CardChooserView(viewModel: viewModel)
        }
        .sheet(isPresented: $showGameCenter) {
            GameCenterView() {
                showGameCenter = false
            }
        }
        .sheet(isPresented: $viewModel.showJackpotSheet) {
            VStack(spacing: 20) {

                Text("🎉 Jackpot Received! 🎉")
                    .font(.largeTitle)
                    .lineLimit(1)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Image("47bill-large")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .padding()
                    .foregroundColor(.white)

                Text("You won \(viewModel.lastJackpotCount) x $47 bills.")
                    .font(.title2)
                    .lineLimit(1)
                    .foregroundColor(.white)

                Text("Total Winnings:")
                    .font(.title)
                    .lineLimit(1)
                    .foregroundColor(.green)
                
                Text("\(viewModel.lastJackpotAmount) credits")
                    .font(.largeTitle)
                    .lineLimit(1)
                    .minimumScaleFactor(0.1)
                    .foregroundColor(.white)
                
                Spacer()
                
                Button {
                    viewModel.showJackpotSheet = false
                } label: {
                    Text("COLLECT")
                        .font(.largeTitle).bold()
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(15)
                        .transition(.opacity)
                        .lineLimit(1)
                        .minimumScaleFactor(0.1)


                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    SoundManager.shared.playSound(.first3)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity) // Ensure full expansion
            .background(Color.black.ignoresSafeArea(edges: .all)) // Move before padding
            .minimumScaleFactor(0.1)
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
            .frame(maxWidth: .infinity, minHeight: 30, maxHeight: height) // Ensures height constraint
            .padding(.horizontal, 16)
            .background(backgroundColor.dimmedIf(isDisabled))
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
                    // Background color logic
                    Rectangle()
                        .fill(isLastCalled ? .yellow : isCalled ? Color.red : Color.blue)
                        .aspectRatio(1, contentMode: .fit)
                        .border(Color.white, width: borderWidth) // Dynamically sized border
                    
                    // Foreground logic
                    if isCalled {
                        Text(space.label) // Show number if called
                            .font(.system(size: columnWidth * 0.55, weight: .bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .foregroundColor(.white)
                            .shadow(color: isLastCalled ? .clear : .black, radius: 0.5, x: 1, y: 1)
                    } else {
                        Image(systemName: "star.fill") // Show star if uncalled
                            .font(.system(size: columnWidth * 0.55, weight: .bold))
                            .foregroundColor(.white)
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
            let isBonusSpace = space.id == BingoViewModel.bonusSpaceID
            let fontSize = space.isFreeSpace ? spaceSize * 0.3 : isBonusSpace ? spaceSize * 0.7 : spaceSize * 0.4

            Text(space.label)
                .font(.system(size: fontSize, weight: .bold))
                .padding(space.isFreeSpace ? 2 : 0)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .foregroundColor(isBonusSpace ? .white : .white)
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
    let dismissAction: () -> Void
    let leaderBoardID = "com.gudmilk.bingo47.leaderboards.credits"

    func makeUIViewController(context: Context) -> GKGameCenterViewController {
        let gameCenterVC = GKGameCenterViewController(leaderboardID: leaderBoardID, playerScope: .global, timeScope: .today)
        gameCenterVC.gameCenterDelegate = context.coordinator
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

extension Color {
    static let gold = Color(red: 1.0, green: 0.84, blue: 0.0) // Classic gold
    static let deepGold = Color(red: 0.85, green: 0.65, blue: 0.13) // Deeper gold, more antique
    static let brightGold = Color(red: 1.0, green: 0.76, blue: 0.03) // Brighter, shinier gold
    
    
    /// Returns a dimmed version of the color based on the provided condition.
    ///
    /// - Parameter isDimmed: A Boolean value indicating whether the color should be dimmed.
    ///   If `true`, the color remains unchanged. If `false`, the color is returned with 25% opacity.
    /// - Returns: A `Color` that is either fully opaque or dimmed based on `isDimmed`.
    func dimmedIf(_ isDimmed: Bool) -> Color {
        return isDimmed ? self.opacity(0.25) : self
    }
}
