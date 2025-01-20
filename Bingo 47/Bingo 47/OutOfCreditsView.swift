//
//  OutOfCreditsView.swift
//  Bingo Tap
//
//  Created by Brandt Dary on 1/17/25.
//

import SwiftUI
import StoreKit

struct OutOfCreditsView: View {
    var allowClose: Bool = false
    
    @Binding var isVisible: Bool
    @ObservedObject var viewModel: BingoViewModel
    @State private var products: [Product] = []

    var body: some View {
        ZStack {
            
            // **1. Background Dimmer to Block Taps**
            Color.black.opacity(isVisible ? 0.5 : 0)
                .edgesIgnoringSafeArea(.all)
                .allowsHitTesting(isVisible)
            
            // **2. Animated Popup**
            VStack(spacing: 20) {
                Text("Out of Credits?")
                    .font(.title)
                    .bold()
                    .foregroundColor(.white)
                
                if viewModel.isProcessingPurchase {
                    Spacer()
                    ProgressView("Processing...")
                        .tint(.white)
                        .padding()
                        .padding(.bottom, 32)
                        .frame(width: 200, height: 200) // Sets the size of the container
                        .scaleEffect(1.5) // Makes the ProgressView 1.5x larger
                        .foregroundStyle(.white)
                    Spacer()
                } else {
                    Text("Choose an option below to get more credits:")
                        .font(.body)
                        .minimumScaleFactor(0.1)
                        .bold()
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center) // Ensures the text is centered
                        .frame(maxWidth: .infinity, alignment: .center) // Expands and centers in its parent view
                    
                    VStack {
                        if products.isEmpty {
                            Text("Loading products...")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.7))
                        } else {
                            HStack(spacing: 8) {
                                ForEach(products, id: \.id) { product in
                                    VStack {
                                        Text(product.displayName)
                                            .font(.headline)
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.25)
                                            .foregroundColor(.white)
                                            .frame(maxWidth: .infinity, minHeight: 20) // Ensures uniformity in the title

                                        Button(action: {
                                            Task {
                                                await viewModel.purchaseCredits(productID: product.id)
                                                isVisible = false
                                            }
                                        }) {
                                            Text(product.displayPrice)
                                                .font(.headline)
                                                .lineLimit(1)
                                                .minimumScaleFactor(0.25)
                                                .foregroundColor(.black)
                                                .frame(maxWidth: .infinity, minHeight: 50) // **Consistent button size**
                                                .background(Color.yellow)
                                                .cornerRadius(8)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, minHeight: 80) // Ensure equal size per product block
                                }
                            }
                        }
                    }
                    
                    VStack {
                        Text(allowClose ? "" : "\(viewModel.freeRefillAmount)")
                            .font(.body).bold()
                            .foregroundStyle(.white)
                        
                        Button(action: {
                            if !allowClose { // their out of credits
                                viewModel.resetCredits()
                            }
                            withAnimation(.spring()) {
                                isVisible = false
                            }
                        }) {
                            Text(allowClose ? "Close" : "Free!")
                                .font(.headline).bold()
                                .foregroundColor(.white)
                                .padding()
                                .padding(.horizontal, 8)
                                .background(Color.red)
                                .cornerRadius(8)
                        }
                        
                        if viewModel.credits >= viewModel.baseBet {
                            Button(action: {
                                viewModel.lowerBetToMaxPossible()
                                withAnimation(.spring()) {
                                    isVisible = false
                                }
                            }) {
                                Text("Lower Bet")
                                    .foregroundColor(.white)
                                    .padding()
                                    .underline()
                            }
                        }
                    }
                }
            }
            .padding()
            .frame(width: 320, height: 400)
            .background(Color.blue)
            .cornerRadius(15)
            .shadow(radius: 10)
            .overlay(
                RoundedRectangle(cornerRadius: 15)
                    .inset(by: 2)
                    .stroke(Color.yellow, lineWidth: 4)
            )
            .offset(y: isVisible ? 0 : UIScreen.main.bounds.height)
            .animation(.spring(), value: isVisible)
        }
        .opacity(isVisible ? 1 : 0)
        .animation(.easeInOut(duration: 0.3), value: isVisible)
        .task {
            await fetchProducts()
        }
    }

    /// Fetch available in-app purchase products
    private func fetchProducts() async {
        do {
            products = try await IAPManager.shared.fetchProducts()
        } catch {
            print("⚠️ Error fetching products: \(error.localizedDescription)")
        }
    }
}
