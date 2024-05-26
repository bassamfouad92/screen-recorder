//
//  LoginService.swift
//  InnerAI
//
//  Created by Bassam Fouad on 06/05/2024.
//

import Foundation
import Combine

protocol LoginService {
    func login(email: String, password: String) -> AnyPublisher<LoginResponse, NetworkError>
}

final class LoginServiceImp: LoginService {
    
    let httpClient: HttpClient
    
    init(httpClient: HttpClient) {
        self.httpClient = httpClient
    }
    
    func login(email: String, password: String) -> AnyPublisher<LoginResponse, NetworkError> {
           let loginRequest = LoginRequest(email: email, password: password)
           
           return Future<LoginResponse, NetworkError> { promise in
               self.httpClient.execute(request: loginRequest, headers: nil) { (result: Result<LoginResponse, NetworkError>)  in
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
