//
//  Request.swift
//  InnerAI
//
//  Created by Bassam Fouad on 05/05/2024.
//

import Foundation

protocol Request {
    var endpoint: String { get }
    var params: [String: Any]? { get }
    var httpMethod: HttpMethod { get }
}

struct LoginRequest: Request {
    
    let email: String
    let password: String
    
    init(email: String, password: String) {
        self.email = email
        self.password = password
    }
    
    var endpoint: String {
        return "\(AppSettings.shared.environment.baseUrl)/api/v1/users/login_with_key"
    }
    
    var params: [String : Any]? {
        return [
            "email" : email,
            "api_key" : password
        ]
    }
    
    var httpMethod: HttpMethod {
        .post
    }
}


struct UploadInitiateRequest: Request {
    
    let type: String
    let name: String
    let size: Int
    let currentSpace: String = UserSessionManager.currentSpace
    let userId: String = UserSessionManager.userId
    let apiKey: String = UserSessionManager.apiKey
    let env: String = AppSettings.shared.environment.rawValue
    
    init(type: String, name: String, size: Int) {
        self.type = type
        self.name = name
        self.size = size
    }
    
    var endpoint: String {
        return AppSettings.shared.environment.uploadInitUrl
    }
    
    var params: [String : Any]? {
        return [
            "type": type,
            "name": name,
            "size": size,
            "current_space": currentSpace,
            "user_id": userId,
            "api_key": apiKey,
            "env": env
        ]
    }
    
    var httpMethod: HttpMethod {
        .post
    }
}

struct UploadCompletionRequest: Request {
    
    let docId: String
    let currentSpace: String = UserSessionManager.currentSpace
    let apiKey: String = UserSessionManager.apiKey

    init(docId: String) {
        self.docId = docId
    }
    
    var endpoint: String {
        return AppSettings.shared.environment.uploadCompleteUrl
    }
    
    var params: [String : Any]? {
        return [
            "doc_id": docId,
            "current_space": currentSpace,
            "api_key": apiKey
        ]
    }
    
    var httpMethod: HttpMethod {
        .post
    }
}
