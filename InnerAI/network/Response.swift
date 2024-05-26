//
//  Response.swift
//  InnerAI
//
//  Created by Bassam Fouad on 05/05/2024.
//

import Foundation

struct LoginResponse: Decodable {
    let status: Int
    let userId: String
    let organizationId: String
    let spaceId: String
    
    enum CodingKeys: String, CodingKey {
        case status
        case userId = "user_id"
        case organizationId = "organization_id"
        case spaceId = "space_id"
    }
}


struct UploadResponse: Decodable {
    let apiType: String
    let bucket: String
    let documentId: String
    let fileName: String
    let key: String
    let name: String
    let preSignedUrl: String
    
    enum CodingKeys: String, CodingKey {
        case apiType = "api_type"
        case bucket
        case documentId = "document_id"
        case fileName = "file_name"
        case key
        case name
        case preSignedUrl
    }
}

struct UploadCompletionResponse: Decodable {
    let status: String?
    let libraryUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case status
        case libraryUrl = "library_url"
    }
    
    func isOK() -> Bool {
        status == "ok"
    }
}
