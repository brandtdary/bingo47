//
//  IAPManager.swift
//  Bingo Tap
//
//  Created by Brandt Dary on 1/17/25.
//

import StoreKit
import SwiftUI

class IAPManager {
    static let shared = IAPManager()

    // Define static constants for product IDs
    static let productCreditsTier1ID = "com.gudmilk.bingotap.credits.tier1"
    static let productCreditsTier2ID = "com.gudmilk.bingotap.credits.tier2"
    static let productCreditsTier3ID = "com.gudmilk.bingotap.credits.tier3"

    
    private let productIdentifiers: [String] = [productCreditsTier1ID, productCreditsTier2ID, productCreditsTier3ID]

    private init() {}

    /// Fetch available in-app purchases from the App Store
    func fetchProducts() async throws -> [Product] {
        do {
            let products = try await Product.products(for: productIdentifiers)
            return products.sorted { $0.price < $1.price }
        } catch {
            throw IAPError.failedToFetchProducts(error.localizedDescription)
        }
    }

    /// Handles purchasing a product and returns success status
    func purchase(productID: String) async throws -> Bool {
        guard let product = try await Product.products(for: [productID]).first else {
            throw IAPError.productNotFound
        }

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    return true  // Purchase successful
                case .unverified:
                    throw IAPError.verificationFailed
                }
            case .pending:
                return false
            case .userCancelled:
                return false
            @unknown default:
                throw IAPError.unknown
            }
        } catch {
            throw IAPError.purchaseFailed(error.localizedDescription)
        }
    }

    /// Listens for transactions asynchronously and returns completed purchases
    func processPendingTransactions() async {
        for await result in Transaction.updates {
            switch result {
            case .verified(let transaction):
                await transaction.finish()
            default:
                print("⚠️ Unverified transaction: \(result)")
            }
        }
    }
}

/// Defines possible purchase errors
enum IAPError: Error, LocalizedError {
    case productNotFound
    case verificationFailed
    case purchaseFailed(String)
    case failedToFetchProducts(String)
    case unknown

    var errorDescription: String? {
        switch self {
        case .productNotFound: return "The requested product could not be found."
        case .verificationFailed: return "Purchase verification failed."
        case .purchaseFailed(let message): return "Purchase failed: \(message)"
        case .failedToFetchProducts(let message): return "Failed to fetch products: \(message)"
        case .unknown: return "An unknown error occurred."
        }
    }
}
