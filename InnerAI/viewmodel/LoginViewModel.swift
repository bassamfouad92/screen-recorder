//
//  LoginViewModel.swift
//  InnerAI
//
//  Created by Bassam Fouad on 06/05/2024.
//

import Foundation
import Combine

class LoginViewModel: ObservableObject {
    
    @Published var email: String = ""
    @Published var password: String = ""
    @Published var isLoading: Bool = false
    @Published var isLoggedIn: Bool = false
    @Published var errorMessage: String?
    @Published var enableLoginButton: Bool = false

    
    private var cancellables = Set<AnyCancellable>()
    private let loginService: LoginService
    
    init(loginService: LoginService) {
        self.loginService = loginService
        
        $email
            .sink { email in
                self.errorMessage = nil
                self.enableLoginButton = !email.isEmpty && !self.password.isEmpty
            }
            .store(in: &cancellables)
        
        $password
            .sink { password in
                self.errorMessage = nil
                self.enableLoginButton = !self.email.isEmpty && !password.isEmpty
            }
            .store(in: &cancellables)
    }
    
    func login() {
        
        if !enableLoginButton {
            return
        }
        
        isLoading = true
        
        loginService.login(email: email.trim(), password: password.trim())
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                    switch completion {
                     case .finished:
                        self?.isLoading = false
                        self?.errorMessage = nil
                        break
                     case .failure(let error):
                        self?.isLoading = false
                        self?.isLoggedIn = false
                        self?.errorMessage = "Invalid credentials"
                        print("Login failed with error: \(error.localizedDescription)")
                    }
                }, receiveValue: { [weak self] loginResponse in
                    print("Login successful with response: \(loginResponse)")
                    UserSessionManager.apiKey = self?.password ?? ""
                    UserSessionManager.currentSpace = loginResponse.spaceId
                    UserSessionManager.userId = loginResponse.userId
                    // notify
                    self?.isLoggedIn = true
                })
                .store(in: &cancellables)
    }
}
