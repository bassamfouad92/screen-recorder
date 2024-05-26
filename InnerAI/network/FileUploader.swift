//
//  FileUploader.swift
//  InnerAI
//
//  Created by Bassam Fouad on 05/05/2024.
//

import Foundation

class FileUploader: NSObject, URLSessionTaskDelegate {
    
    typealias UploadCompletionHandler = (Error?) -> Void
    typealias UploadProgressHandler = (Double) -> Void
    
    private var session: URLSession!
    private var uploadTask: URLSessionUploadTask?
    
    var uploadCompletionHandler: UploadCompletionHandler?
    var uploadProgressHandler: UploadProgressHandler?
    
    override init() {
        super.init()
        session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
    }
    
    func uploadFile(from url: URL, to serverURL: URL) {
        
        var uploadRequest = URLRequest(url: serverURL)
        uploadRequest.addValue("video/mp4", forHTTPHeaderField: "Content-Type")
        uploadRequest.httpMethod = "PUT"
        
        print("FileUploader fileUrl: \(url), serverUrl: \(serverURL)")
        
        uploadTask = session.uploadTask(with: uploadRequest, fromFile: url, completionHandler: { responseData, response, error in
            DispatchQueue.main.async {
                     print("FileUploader task responseCode: \((response as? HTTPURLResponse)?.statusCode)")
                     guard let responseCode = (response as? HTTPURLResponse)?.statusCode, responseCode == 200  else {
                           if let error = error {
                               self.uploadCompletionHandler?(error)
                           }
                           return
                       }
                      self.uploadCompletionHandler?(nil)
                   }
        })
        uploadTask?.resume()
    }
    
    func cancelUpload() {
        uploadTask?.cancel()
    }
    
    // MARK: - URLSessionTaskDelegate
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        let uploadProgress = Double(totalBytesSent) / Double(totalBytesExpectedToSend)
        self.uploadProgressHandler?(uploadProgress)
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            self.uploadCompletionHandler?(error)
        } else {
            self.uploadCompletionHandler?(nil)
        }
    }
}
