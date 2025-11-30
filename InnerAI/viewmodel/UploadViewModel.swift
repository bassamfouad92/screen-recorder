//
//  UploadViewModel.swift
//  InnerAI
//
//  Created by Bassam Fouad on 05/05/2024.
//

import Foundation
import Combine

class UploadViewModel: ObservableObject {
    
    @Published var isLoading: Bool = true
    @Published var showErrorState: Bool = false
    @Published var showSuccessState: Bool = false
    @Published var progressPercentage: Double = 0.0
    @Published var uploadedVideoUrl: String = ""

    private var cancellables = Set<AnyCancellable>()
    private let uploadService: UploadService
    private let fileUploader: FileUploader = FileUploader()
    private let fileInfo: FileInfo
    private var docId: String?

    init(uploadService: UploadService, fileInfo: FileInfo) {
        self.uploadService = uploadService
        self.fileInfo = fileInfo
    }
    
    func initUpload() {
        
        isLoading = true
        showErrorState = false
        showSuccessState = false
        
        uploadService.initiateUpload(input: Upload.Input(fileType: fileInfo.type, fileName: fileInfo.name, fileSize: fileInfo.size))
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] completion in
                    switch completion {
                     case .finished:
                        self?.isLoading = false
                        break
                     case .failure(_):
                        self?.isLoading = false
                        self?.showErrorState = true
                    }
                }, receiveValue: { [weak self] uploadOutput in
                    print("Upload initiated successfully with output: \(uploadOutput)")
                    self?.docId = uploadOutput.documentId
                    self?.uploadFile(toS3bucket: uploadOutput.bucketUrl)
                })
                .store(in: &cancellables)
    }

    private func uploadFile(toS3bucket url: String) {
        
        guard let bucketUrl = URL(string: url) else {
            return
        }
        
        fileUploader.uploadFile(from: fileInfo.url, to: bucketUrl)
        fileUploader.uploadProgressHandler = { [weak self] uploadProgress in
            DispatchQueue.main.async {
                self?.progressPercentage = uploadProgress
            }
        }
        fileUploader.uploadCompletionHandler = { [weak self] error in
            DispatchQueue.main.async {
                if let _ = error {
                    self?.showErrorState = true
                } else {
                    self?.showSuccessState = true
                    self?.notifyUploadComplete()
                }
            }
        }
    }
    
    private func notifyUploadComplete() {
        if let docId = self.docId {
            self.uploadService.completeUpload(documentId: docId).receive(on: DispatchQueue.main)
                .sink(receiveCompletion: { completion in
                        switch completion {
                         case .finished:
                            break
                         case .failure(_):
                            print("failed")
                        }
                    }, receiveValue: { [weak self] uploaded in
                        if let url = uploaded.libraryUrl {
                            //delete all mp4 files
                            RecordFileManager.shared.deleteAllMP4Files()
                            self?.uploadedVideoUrl = url
                        }
                    })
                .store(in: &self.cancellables)
        }
    }
    
    
    func cancelUpload() {
        //delete all mp4 files
        //RecordFileManager.shared.deleteAllMP4Files()
        fileUploader.cancelUpload()
    }
    
}
