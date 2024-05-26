//
//  ActivityIndicatorWithText.swift
//  InnerAI
//
//  Created by Bassam Fouad on 04/05/2024.
//

import SwiftUI

struct ActivityIndicatorWithText: View {
    @State private var isLoading = false
        let text: String
        
        var body: some View {
            VStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .padding()
                    Text(text)
                        .font(.headline)
                }
            }
            .onAppear {
                isLoading = true
            }
            .onDisappear {
                isLoading = false
            }
        }
}
