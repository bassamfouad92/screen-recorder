//
//  UserSettings.swift
//  InnerAI
//
//  Created by Bassam Fouad on 05/05/2024.
//

import Foundation

struct AppSettings {
    
    // Define a static constant instance
    static let shared = AppSettings()
    
    // Define the environment property
    let environment: Environment
    
    // Private initializer to prevent external initialization
    private init() {
        environment = .production // Default environment
    }
}

