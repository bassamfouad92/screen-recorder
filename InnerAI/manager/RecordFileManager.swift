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
        
        // Dynamically get the user's home directory path and append the inneraivideos path
        let directoryURL = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Documents/inneraivideos")
        
        // Check if the directory exists
        guard fileManager.fileExists(atPath: directoryURL.path) else {
            print("Directory not found at path: \(directoryURL.path)")
            return
        }
        
        do {
            let contents = try fileManager.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: nil)
            for fileURL in contents {
                if fileURL.pathExtension.lowercased() == "mp4" || fileURL.pathExtension.lowercased() == "mov" {
                    try fileManager.removeItem(at: fileURL)
                    print("Deleted file: \(fileURL.lastPathComponent)")
                }
            }
        } catch {
            print("Error deleting files: \(error)")
        }
    }
    
    func fetchFileInfo(fromPath fileURL: URL) -> (fileSize: Int, fileType: String, fileName: String, fileURL: URL)? {
            let fileManager = FileManager.default
            //let fileURL = URL(fileURLWithPath: path)
            
            do {
                let attributes = try fileManager.attributesOfItem(atPath: fileURL.relativePath)
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
