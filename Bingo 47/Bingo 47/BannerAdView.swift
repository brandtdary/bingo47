//
//  BannerAdView.swift
//  GudBingo
//
//  Created by Brandt Dary on 1/2/25.
//

import SwiftUI
import GoogleMobileAds

struct BannerAdView: UIViewRepresentable {
//    let adUnitID = "ca-app-pub-3940256099942544/2934735716" // TEST
    let adUnitID = "ca-app-pub-6362408680341882/2676851997" // REAL

    @Binding var isAdLoaded: Bool

    func makeUIView(context: Context) -> GADBannerView {
        let bannerView = GADBannerView(adSize: GADAdSizeBanner)
        bannerView.adUnitID = adUnitID
        bannerView.rootViewController = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?.rootViewController
        bannerView.delegate = context.coordinator

        // Load the ad asynchronously
        Task {
            await loadAd(for: bannerView)
        }
        
        return bannerView
    }

    func updateUIView(_ uiView: GADBannerView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        return Coordinator(isAdLoaded: $isAdLoaded)
    }

    private func loadAd(for bannerView: GADBannerView) async {
        let request = GADRequest()

        // Call the async requestTrackingAuthorization method
        let isAuthorized = await AppTrackingHelper.requestTrackingAuthorization()
        
        if !isAuthorized {
            let extras = GADExtras()
            extras.additionalParameters = ["npa": "1"] // Non-personalized ads
            request.register(extras)
        }
        
        // Load the ad
        bannerView.load(request)
    }

    class Coordinator: NSObject, GADBannerViewDelegate {
        @Binding var isAdLoaded: Bool
        
        init(isAdLoaded: Binding<Bool>) {
            self._isAdLoaded = isAdLoaded
        }
        
        func adViewDidReceiveAd(_ bannerView: GADBannerView) {
            isAdLoaded = true
        }
        
        func bannerView(_ bannerView: GADBannerView, didFailToReceiveAdWithError error: Error) {
            isAdLoaded = false
            print("Ad failed to load with error: \(error.localizedDescription)")
        }
    }
}
