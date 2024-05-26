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
            return "https://platformapi-staging.innerplay.io"
        case .production:
            return "https://platformapi.innerplay.io"
        }
    }
    
    var uploadInitUrl: String {
        switch self {
        case .staging:
            return "https://processing-staging.innerplay.io:5000/cloud_upload_init"
        case .production:
            return "https://processing.innerplay.io:5000/cloud_upload_init"
        }
    }
    
    var uploadCompleteUrl: String {
        switch self {
        case .staging:
            return "https://service-staging.innerplay.io/cloud-upload-done"
        case .production:
            return "https://service.innerplay.io/cloud-upload-done"
        }
    }
}
