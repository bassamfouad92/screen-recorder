//
//  FileUtils.swift
//  InnerAI
//
//  Created by Bassam Fouad on 20/07/2024.
//

import Foundation

struct FileUtils {
    public static func createDirectoryInDocuments(withName name: String) {
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let newDirectoryURL = documentsURL.appendingPathComponent(name)
        
        if !fileManager.fileExists(atPath: newDirectoryURL.path) {
            do {
                try fileManager.createDirectory(at: newDirectoryURL, withIntermediateDirectories: true, attributes: nil)
                print("Directory created at path: \(newDirectoryURL.path)")
            } catch {
                print("Failed to create directory: \(error)")
            }
        } else {
            print("Directory already exists at path: \(newDirectoryURL.path)")
        }
    }
}
