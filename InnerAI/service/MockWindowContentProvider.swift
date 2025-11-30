//
//  MockWindowContentProvider.swift
//  InnerAI
//
//  Created by Bassam Fouad on 30/11/2025.
//

import Foundation
import ScreenCaptureKit

#if DEBUG
final class MockWindowContentProvider: WindowContentProvider {
    
    var mockExcludedWindows: [WindowReference] = []
    var mockWindow: WindowReference?
    var shouldThrowError = false
    
    func getExcludedWindows(withTitles titles: [String]) async throws -> [WindowReference] {
        if shouldThrowError {
            throw NSError(domain: "MockError", code: -1)
        }
        return mockExcludedWindows
    }
    
    func getWindow(withTitle title: String) async throws -> WindowReference? {
        if shouldThrowError {
            throw NSError(domain: "MockError", code: -1)
        }
        return mockWindow
    }
    
    func getWindow(withID windowID: CGWindowID) async throws -> WindowReference? {
        if shouldThrowError {
            throw NSError(domain: "MockError", code: -1)
        }
        return mockWindow
    }
}
#endif
