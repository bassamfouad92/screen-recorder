//
//  Environment.swift
//  InnerAI
//
//  Created by Bassam Fouad on 05/05/2024.
//

import Foundation

enum Environment: String {
    case staging
    case production
    
    var baseUrl: String {
        switch self {
        case .staging:
            return "https://platformapi-staging.com"
        case .production:
            return "https://platformapi.com"
        }
    }
    
    var uploadInitUrl: String {
        switch self {
        case .staging:
            return "https://processing-staging.io/cloud_upload_init"
        case .production:
            return "https://processing.io/cloud_upload_init"
        }
    }
    
    var uploadCompleteUrl: String {
        switch self {
        case .staging:
            return "https://service-staging.io/cloud-upload-done"
        case .production:
            return "https://service.io/cloud-upload-done"
        }
    }

    var platformUrl: String {
        switch self {
        case .staging:
            return "https://app-staging.com"
        case .production:
            return "https://app.com"
        }
    }
}
