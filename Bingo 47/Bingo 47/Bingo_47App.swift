//
//  Bingo_47App.swift
//  Bingo 47
//
//  Created by Brandt Dary on 1/19/25.
//

import SwiftUI
import GoogleMobileAds

@main
struct Bingo_47App: App {
    init() {
        GADMobileAds.sharedInstance().start(completionHandler: nil)
    }

    var body: some Scene {
        WindowGroup {
            BingoView()
        }
    }
}
