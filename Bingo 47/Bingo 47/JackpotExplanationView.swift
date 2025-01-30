//
//  JackpotExplanationView.swift
//  Bingo Tap
//
//  Created by Brandt Dary on 1/29/25.
//

import SwiftUI

struct JackpotExplanationView: View {
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 20) {
            Text("How the **Jackpot** works:")
                .font(.title2)
                .bold()
            
            Image("47bill-large")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .padding()
                .foregroundColor(.white)


            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Text("• Mark **47** to collect $47 bills, multiplied by your bet level.")
                    Text("• Example: Betting 500 (5× base bet, 100) earns 5× $47 bills.")
                    Text("• Each **bet level** has its own jackpot.")
                    Text("• You win the jackpot when you get a **blackout**.")
                }
            }
            .minimumScaleFactor(0.5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            
            Button("Got it") {
                isPresented = false
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(15)
            .padding(.horizontal)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.secondary)
    }
}
