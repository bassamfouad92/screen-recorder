//
//  RecordFileManager.swift
//  InnerAI
//
//  Created by Bassam Fouad on 05/05/2024.
//

import Foundation

class RecordFileManager {
    static let shared = RecordFileManager()
    
    private init() {}
    
    func deleteFile(atPath path: String) {
        let fileManager = FileManager.default
        do {
            try fileManager.removeItem(atPath: path)
            print("File deleted successfully")
        } catch {
            print("Error deleting file: \(error)")
        }
    }
    
    func deleteAllMP4Files() {
        let fileManager = FileManager.default
            do {
                let directoryURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                let contents = try fileManager.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil)
                for fileURL in contents {
                    if fileURL.pathExtension == "mp4" || fileURL.pathExtension == "mov" {
                        try fileManager.removeItem(at: fileURL)
                        print("Deleted file: \(fileURL.lastPathComponent)")
                    }
                }
            } catch {
                print("Error deleting files: \(error)")
            }
    }
    
    func fetchFileInfo(fromPath path: String) -> (fileSize: Int, fileType: String, fileName: String, fileURL: URL)? {
            let fileManager = FileManager.default
            let fileURL = URL(fileURLWithPath: path)
            
            do {
                let attributes = try fileManager.attributesOfItem(atPath: path)
                let fileSize = attributes[.size] as? Int ?? 0
                let fileType = fileURL.pathExtension
                let fileName = fileURL.lastPathComponent
                
                return (fileSize, fileType, fileName, fileURL)
            } catch {
                print("Error fetching file info: \(error)")
                return nil
            }
    }
}
