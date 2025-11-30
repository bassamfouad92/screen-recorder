//
//  WindowContentService.swift
//  InnerAI
//
//  Created by Bassam Fouad on 30/11/2025.
//

import Foundation
import ScreenCaptureKit

protocol WindowContentProvider {
    func getExcludedWindows(withTitles titles: [String]) async throws -> [WindowReference]
    func getWindow(withTitle title: String) async throws -> WindowReference?
    func getWindow(withID windowID: CGWindowID) async throws -> WindowReference?
}

final class SCKWindowContentService: WindowContentProvider {
    
    func getExcludedWindows(withTitles titles: [String]) async throws -> [WindowReference] {
        let content = try await SCShareableContent.current
        let windows = content.windows.filter { window in
            titles.contains(window.title ?? "")
        }
        return windows.map { WindowReference($0) }
    }
    
    func getWindow(withTitle title: String) async throws -> WindowReference? {
        let content = try await SCShareableContent.current
        guard let window = content.windows.first(where: { $0.title == title }) else {
            return nil
        }
        return WindowReference(window)
    }
    
    func getWindow(withID windowID: CGWindowID) async throws -> WindowReference? {
        let content = try await SCShareableContent.current
        guard let window = content.windows.first(where: { $0.windowID == windowID }) else {
            return nil
        }
        return WindowReference(window)
    }
}
