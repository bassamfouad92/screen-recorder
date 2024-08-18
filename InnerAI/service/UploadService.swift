//
//  UploadService.swift
//  InnerAI
//
//  Created by Bassam Fouad on 06/05/2024.
//

import Foundation
import Combine

enum Upload {
    struct Input {
        let fileType: String
        let fileName: String
        let fileSize: Int
    }
    struct Output {
        let documentId: String
        let bucketUrl: String
    }
}

protocol UploadService {
    func initiateUpload(input: Upload.Input) -> AnyPublisher<Upload.Output, NetworkError>
    func completeUpload(documentId: String) -> AnyPublisher<UploadCompletionResponse, NetworkError>
}


final class UploadServiceImp: UploadService {
    
    let httpClient: HttpClient
    
    init(httpClient: HttpClient) {
        self.httpClient = httpClient
    }
    
    func initiateUpload(input: Upload.Input) -> AnyPublisher<Upload.Output, NetworkError> {
        
        let uploadRequest = UploadInitiateRequest(type: input.fileType, name: input.fileName, size: input.fileSize)
        
        return Future<Upload.Output, NetworkError> { promise in
            self.httpClient.execute(request: uploadRequest, headers: nil) { (result: Result<UploadResponse, NetworkError>)  in
                switch result {
                case .success(let data):
                    promise(.success(Upload.Output(documentId: data.documentId, bucketUrl: data.preSignedUrl)))
                case .failure(let error):
                    print("UploadInitiateRequest: EEROR:::: \(error)")
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    func completeUpload(documentId: String) -> AnyPublisher<UploadCompletionResponse, NetworkError> {
        let uploadRequest = UploadCompletionRequest(docId: documentId)
        
        return Future<UploadCompletionResponse, NetworkError> { promise in
            self.httpClient.execute(request: uploadRequest, headers: nil) { (result: Result<UploadCompletionResponse, NetworkError>)  in
                switch result {
                case .success(let data):
                    promise(.success(data))
                case .failure(let error):
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
}
