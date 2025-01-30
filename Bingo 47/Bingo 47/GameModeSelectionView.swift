//
//  GameModeSelectionView.swift
//  Bingo 47
//
//  Created by Brandt Dary on 1/29/25.
//

import SwiftUI

struct GameModeSelectionView: View {
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 20) {
            Text("Welcome to")
                .font(.title)
                .bold()
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            Text("🎉 Bingo 47! 🎉")
                .font(.largeTitle)
                .bold()
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            Text("Choose how you want to play.")
                .multilineTextAlignment(.center)
                .foregroundColor(.white)
                .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 16) { // ✅ Ensures left alignment
                Button(action: {
                    selectMode(classic: true)
                }) {
                    VStack(alignment: .leading) { // ✅ Left-aligns everything inside
                        Text("🎙️ Classic Mode")
                            .font(.title2)
                            .bold()
                        Text("""
                        • Numbers are called
                        • Tap to mark numbers
                        • Normal speed
                        """)
                        .multilineTextAlignment(.leading) // ✅ Ensures bullet alignment
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }

                Button(action: {
                    selectMode(classic: false)
                }) {
                    VStack(alignment: .leading) { // ✅ Ensures Turbo Mode text is left-aligned
                        Text("⚡ Turbo Mode")
                            .font(.title2)
                            .bold()
                        Text("""
                        • No spoken numbers
                        • Numbers auto-marked
                        • Fast speed
                        """)
                        .multilineTextAlignment(.leading) // ✅ Left-aligns bullet points
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
            }
            .padding(.horizontal)
            
            VStack(alignment: .center) {
                Text("You can change this later in Settings.")
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white)
                    .padding(.horizontal)
            }

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black) // Dark background
    }

    private func selectMode(classic: Bool) {
        let defaults = UserDefaults.standard
        if classic {
            defaults.set(false, forKey: GameSettingsKeys.autoMark)
            defaults.set(true, forKey: GameSettingsKeys.speakSpaces)
            defaults.set(GameSpeedOption.normal.rawValue, forKey: GameSettingsKeys.gameSpeed)
        } else {
            defaults.set(true, forKey: GameSettingsKeys.autoMark)
            defaults.set(false, forKey: GameSettingsKeys.speakSpaces)
            defaults.set(GameSpeedOption.lightening.rawValue, forKey: GameSettingsKeys.gameSpeed)
        }
        defaults.set(true, forKey: GameSettingsKeys.hasSeenGameModeSelection) // Prevents showing again
        isPresented = false
    }
}
