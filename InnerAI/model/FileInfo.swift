//
//  FileInfo.swift
//  InnerAI
//
//  Created by Bassam Fouad on 06/05/2024.
//

import Foundation

protocol FileProtocol: Equatable {
    var url: URL { get }
    var name: String { get }
    var size: Int { get }
    var type: String { get }
}

struct FileInfo: FileProtocol {
    var url: URL
    var name: String
    var size: Int
    var type: String
}
