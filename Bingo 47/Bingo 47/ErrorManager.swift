//
//  ErrorManager.swift
//  App by GudMilk
//
//  Created by Brandt Dary on 1/30/25.
//

import Foundation
import NotificationCenter

final class ErrorManager {
    
    /// Logs an error message with optional printing and posting.
    /// - Parameters:
    ///   - message: The error message to log.
    ///   - function: The function where the error occurred (auto-filled).
    ///   - shouldPrint: Whether to print the error message (default: true).
    ///   - shouldPost: Whether to post a notification (default: true).
    static func log(_ message: String, function: String = #function, shouldPrint: Bool = true, shouldPost: Bool = true) {
        guard AppConfig.isProductionBuild == false else { return }
        if shouldPrint {
            #if DEBUG
            print(message)
            #endif
        }
        
        if shouldPost {
            NotificationCenter.default.post(name: .errorNotification, object: nil, userInfo: ["message": message, "function": function])
        }
    }
}

// Ensure `.errorNotification` exists globally
extension Notification.Name {
    static let errorNotification = Notification.Name("errorNotification")
}
