//
//  UserSessionManager.swift
//  InnerAI
//
//  Created by Bassam Fouad on 05/05/2024.
//

import Foundation

struct UserSessionManager {
    
    private static let tokenKey = "api_key"
    private static let currentSpaceKey = "current_space"
    private static let userIdKey = "user_id"

    static var apiKey: String {
        get {
            UserDefaults.standard.string(forKey: tokenKey) ?? ""
        }
        set {
            UserDefaults.standard.setValue(newValue, forKey: tokenKey)
        }
    }
    
    static var currentSpace: String {
        get {
            UserDefaults.standard.string(forKey: currentSpaceKey) ?? ""
        }
        set {
            UserDefaults.standard.setValue(newValue, forKey: currentSpaceKey)
        }
    }
    
    static var userId: String {
        get {
            UserDefaults.standard.string(forKey: userIdKey) ?? ""
        }
        set {
            UserDefaults.standard.setValue(newValue, forKey: userIdKey)
        }
    }


    public static func isUserLoggedIn() -> Bool {
        return !userId.isEmpty
    }

    public static func logout() {
        UserDefaults.standard.removeObject(forKey: tokenKey)
        UserDefaults.standard.removeObject(forKey: currentSpaceKey)
        UserDefaults.standard.removeObject(forKey: userIdKey)
    }
}
