//
//  AppConfigurator.swift
//  InnerAI
//
//  Created by Bassam Fouad on 06/05/2024.
//

import Foundation

struct AppConfigurator {
    public static let client = HttpClientImplementation()
    
    public static func configureLoginViewModel() -> LoginViewModel {
        let loginService = LoginServiceImp(httpClient: AppConfigurator.client)
        return LoginViewModel(loginService: loginService)
    }
    
    public static func configureUploadViewModel(with fileInfo: FileInfo) -> UploadViewModel {
        let service = UploadServiceImp(httpClient: AppConfigurator.client)
        return UploadViewModel(uploadService: service, fileInfo: fileInfo)
    }
}
