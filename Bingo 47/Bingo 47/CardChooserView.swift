//
//  CardChooserView.swift
//  Bingo 47
//
//  Created by Brandt Dary on 1/17/25.
//


import SwiftUI

struct CardChooserView: View {
    @ObservedObject var viewModel: BingoViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var previousCard: BingoCard? = nil

    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                let safeAreaTop = geometry.safeAreaInsets.top
                let safeAreaBottom = geometry.safeAreaInsets.bottom
                let totalHeight = geometry.size.height - (safeAreaTop + safeAreaBottom) // Adjust for safe area
                let cardSize = min(totalHeight * 0.40, 500) // Prioritize height, but limit to max 500px

                VStack(spacing: 0) {
                    Spacer()
                    if let currentCard = viewModel.bingoCards.first {                        
                        ZStack {
                            BingoCardView(
                                bingoCard: currentCard,
                                calledSpaces: viewModel.calledSpaces,
                                bingoSpaces: viewModel.findBingoSpaces(for: currentCard),
                                viewModel: viewModel,
                                cardSize: cardSize
                            )
                            
                            if let card = previousCard, card.id != currentCard.id {
                                Button {
                                    viewModel.setBingoCards([card])
                                    previousCard = nil
                                } label: {
                                    VStack {
                                        Text("Undo")
                                            .font(.footnote)
                                    }
                                }
                                .offset(x: -(cardSize / 1.5))
                                
                            }
                        }
                        
                        // Heart button for adding/removing from favorites
                        let isFavorite = viewModel.favoriteBingoCards.contains { $0.id == currentCard.id }
                        Button {
                            if isFavorite {
                                viewModel.removeCardFromFavorites(currentCard)
                            } else {
                                viewModel.favoriteCard(currentCard)
                            }
                        } label: {
                            // Color the heart pink if favorite, gray if not
                            Image(systemName: "heart.fill")
                                .font(.title)
                                .minimumScaleFactor(0.1)
                                .frame(maxHeight: 44)
                                .foregroundStyle(isFavorite ? Color.pink : .gray)
                        }
                        .padding(.top)
                        
                    } else {
                        Text("No current card found.")
                            .foregroundStyle(.white)
                    }
                    
                    Spacer()
                    
                    Divider()
                    
                    // -- Favorites Section
                    let favoriteText = viewModel.favoriteBingoCards.isEmpty ? "Favorite cards will show up here..." : "Your Favorites"
                    Text(favoriteText)
                        .padding(.top)
                        .font(.headline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.1)
                        .foregroundStyle(.white)
                        .frame(maxHeight: 44)
                    
                    ScrollView(.horizontal, showsIndicators: true) {
                        HStack(alignment: .top, spacing: 16) {
                            ForEach(viewModel.favoriteBingoCards) { favorite in
                                VStack(spacing: 8) {
                                    BingoCardView(
                                        bingoCard: favorite,
                                        calledSpaces: viewModel.calledSpaces,
                                        bingoSpaces: viewModel.findBingoSpaces(for: favorite),
                                        viewModel: viewModel,
                                        cardSize: cardSize * 0.75
                                    )
                                    
                                    HStack {
                                        Button {
                                            viewModel.removeCardFromFavorites(favorite)
                                        } label: {
                                            Image(systemName: "heart.fill")
                                                .font(.title)
                                                .minimumScaleFactor(0.1)
                                                .frame(maxHeight: 44)
                                                .foregroundColor(.pink)
                                        }
                                        .buttonStyle(.plain)
                                        
                                        Button {
//                                            if let currentCard = viewModel.bingoCards.first { // We're assuming here, since there's no way not to have a card.
//                                                previousCard = currentCard
//                                            }
                                            viewModel.setBingoCards([favorite])
                                            dismiss()
                                        } label: {
                                            Image(systemName: "play.circle")
                                                .font(.title)
                                                .foregroundColor(.green)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.vertical)
                                .frame(width: cardSize * 0.8) // Make sure this matches your cardSize
                            }
                        }
                        .padding(.horizontal)
                    }
                    .frame(height: cardSize * 1.15)
                    
                }
                .padding(.bottom)
                .background(.black)
                .toolbar {
                    // "Done" button
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                    
                    // "Random Card" button
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Random Card") {
                            viewModel.generateNewCard()
                        }
                    }
                }
            }
        }
    }
}
