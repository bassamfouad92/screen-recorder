//
//  CircularProgressWithText.swift
//  InnerAI
//
//  Created by Bassam Fouad on 04/05/2024.
//

import SwiftUI

struct CircularProgressWithText: View {
    
    @Binding var progress: Double
    
    let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect() // Adjust the timer interval as needed
    let totalProgress: Double = 1.0 // Total progress value
    
    var body: some View {
        VStack {
            ZStack {
                Circle()
                    .stroke(lineWidth: 10.0)
                    .opacity(0.3)
                    .foregroundColor(.progressBarUnfilled)
                
                Circle()
                    .trim(from: 0.0, to: CGFloat(progress))
                    .stroke(style: StrokeStyle(lineWidth: 10.0, lineCap: .round, lineJoin: .round))
                    .fill(LinearGradient(
                        gradient: Gradient(colors: [
                            Color(red: 113/255, green: 99/255, blue: 255/255),
                            Color(red: 156/255, green: 146/255, blue: 248/255),
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    ))
                    .rotationEffect(Angle(degrees: -90))
                
                // Optional: Add a text view to show percentage if needed
                Text(String(format: "%.0f%%", progress * 100))
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(red: 113/255, green: 99/255, blue: 255/255),
                                    Color(red: 156/255, green: 146/255, blue: 248/255),
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                
            }
            .shadow(color: Color.gray.opacity(0.6), radius: 8, x: 0, y: 4)
            .frame(width: 100, height: 100)
            
        }
        /*.onReceive(timer) { _ in
            // Update progress
            if progress < totalProgress {
                progress += 0.01 // Adjust the increment value as needed
            }
        }
        .onAppear {
            progress = 0.0 // Reset progress when the view appears
        }*/
    }
}
