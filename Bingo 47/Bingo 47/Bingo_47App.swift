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
        if AppConfig.isProductionBuild == false {
            GADMobileAds.sharedInstance().requestConfiguration.testDeviceIdentifiers = [ "12f981878b6c3e13a3f518914f69bd2a" ]
        }
    }

    var body: some Scene {
        WindowGroup {
            BingoView()
        }
    }
}
