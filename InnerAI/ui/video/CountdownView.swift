//
//  CountdownView.swift
//  InnerAI
//
//  Created by Bassam Fouad on 18/07/2024.
//

import SwiftUI

struct CountdownView: View {
    let screenSize = NSScreen.main?.frame.size ?? .zero

    @State private var counter: Int = 3
    @State private var isAnimating: Bool = false

    var body: some View {
        ZStack {
            Color.black // Background color
                .edgesIgnoringSafeArea(.all)

            Text("\(counter)")
                .font(.system(size: 100))
                .fontWeight(.bold)
                .foregroundColor(.white)
                .opacity(isAnimating ? 1.0 : 0.0)
                .scaleEffect(isAnimating ? 1.0 : 0.5)
                .onAppear {
                    startCountdown()
                }
        }.frame(maxWidth: screenSize.width, maxHeight: screenSize.height, alignment: .center)
            .edgesIgnoringSafeArea(.all)
            .background(.black)
    }

    private func startCountdown() {
        isAnimating = true
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            withAnimation(.easeInOut(duration: 1.0)) {
                if counter > 0 {
                    counter -= 1
                } else {
                    timer.invalidate()
                }
            }
        }
    }
}

struct CountdownView_Previews: PreviewProvider {
    static var previews: some View {
        CountdownView()
    }
}
