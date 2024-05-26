//
//  String+Trim.swift
//  InnerAI
//
//  Created by Bassam Fouad on 08/05/2024.
//

import Foundation

extension String {
    func trim() -> String {
        return self.trimmingCharacters(in: NSCharacterSet.whitespaces)
    }
}

extension CFString {
    var string: String {
        return self as String
    }
}
