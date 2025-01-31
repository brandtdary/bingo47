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
    private var adCompletionHandler: (() -> Void)?

    init(adUnitID: String) {
        self.adUnitID = adUnitID
        super.init()
        loadAd()
    }

    /// Loads a new rewarded ad
    func loadAd() {
        GADRewardedAd.load(withAdUnitID: adUnitID, request: GADRequest()) { [weak self] ad, error in
            if let error = error {
                ErrorManager.log("Failed to load rewarded ad: \(error.localizedDescription)")
                self?.rewardedAd = nil
            } else {
                self?.rewardedAd = ad
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

        rewardedAd.present(fromRootViewController: rootViewController) { [weak self] in
            NotificationCenter.default.post(name: .rewardedAdDidFinish, object: nil)
            self?.adCompletionHandler = nil
            self?.loadAd()
            completion()
        }
    }

    /// Checks if the ad is ready to be shown
    var isAdReady: Bool {
        rewardedAd != nil
    }
}
