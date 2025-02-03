//
//  RewardedAdViewModel.swift
//  Bingo 47
//
//  Created by Brandt Dary on 1/21/25.
//

import GoogleMobileAds
import UIKit

@MainActor
class RewardedAdViewModel: NSObject {
    private var rewardedAd: GADRewardedAd?
    private var adUnitID: String

    init(adUnitID: String) {
        self.adUnitID = adUnitID
        super.init()
        loadAd()
    }

    /// Loads a new rewarded ad
    func loadAd() {
        GADRewardedAd.load(withAdUnitID: adUnitID, request: GADRequest()) { [weak self] ad, error in
            if let error = error {
                ErrorManager.log("❌ Failed to load rewarded ad: \(error.localizedDescription)")
                self?.rewardedAd = nil
            } else if ad != nil {
                self?.rewardedAd = ad
            } else {
                ErrorManager.log("❌ There was no error... but also no ad.")
            }
        }
    }

    /// Shows the ad if it's ready, otherwise loads a new one
    func showAd(completion: @escaping () -> Void) {
        guard let rootViewController = UIApplication.shared.rootViewController else {
            ErrorManager.log("⚠️ Unable to get rootViewController")
            completion()
            return
        }

        guard let rewardedAd = rewardedAd else {
            ErrorManager.log("⚠️ No ad available, attempting to reload...")
            completion()
            loadAd()
            return
        }
        
        if rootViewController.presentedViewController == nil {
            rewardedAd.present(fromRootViewController: rootViewController) { [weak self] in
                ErrorManager.log("✅ Ad Presented from Root View Controller")
                NotificationCenter.default.post(name: .rewardedAdDidFinish, object: nil)
                self?.rewardedAd = nil
                self?.loadAd()
                completion()
            }
            ErrorManager.log("✅ Ad Presented from Root View Controller")
        } else {
            ErrorManager.log("❌ Rootview Controller wasn't nil")

        }

        
    }

    /// Checks if the ad is ready to be shown
    var isAdReady: Bool {
        let ready = rewardedAd != nil
        return ready
    }
}
