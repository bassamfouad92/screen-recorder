//
//  ControlPanelView.swift
//  InnerAI
//
//  Created by Bassam Fouad on 02/05/2024.
//

import SwiftUI
import Combine

enum RecordingAction {
    case stop
    case pause
    case resume
    case restart
    case delete
    case drag
}

struct ControlPanelView: View {
    
    @State var isPlaying: Bool = true
    @State var lastTime: Date = Date()
    @State var timerString: String = "0:00"
    @Binding var restartRecording: Bool
    @Binding var isPopupDisplayed: Bool

    var onClicked: (RecordingAction) -> Void
    
    var body: some View {
            LazyHStack(spacing: 10) {
                Button(action: {
                    onClicked(.stop)
                }) {
                    Image("stop_icon")
                        .resizable()
                        .frame(width: 24, height: 24)
                }.buttonStyle(.plain)
                TimerView(timerString: $timerString, isRestart: $restartRecording, isPlaying: $isPlaying, lastTime: $lastTime)
                if isPlaying {
                    Button(action: {
                        isPlaying = false
                        onClicked(.pause)
                    }) {
                        Image("pause_icon")
                            .resizable()
                            .frame(width: 24, height: 24)
                    }.buttonStyle(.plain)
                } else {
                    Button(action: {
                        isPlaying = true
                        onClicked(.resume)
                    }) {
                        Image("play_icon")
                            .resizable()
                            .frame(width: 24, height: 24)
                    }.buttonStyle(.plain)
                }
                
                Image("line")
                    .resizable()
                    .frame(width: 2, height: 24)
                Button(action: {
                    onClicked(.restart)
                }) {
                    Image("restart_icon")
                        .resizable()
                        .frame(width: 24, height: 24)
                }.buttonStyle(.plain)
                Button(action: {
                    onClicked(.delete)
                }) {
                    Image("delete_icon")
                        .resizable()
                        .frame(width: 24, height: 24)
                }.buttonStyle(.plain)
                Text(" ")
                    .frame(width: 24, height: 24)
            }
            .onChange(of: restartRecording) { newValue in
                if newValue {
                    restartRecording = false
                    isPlaying = true
                }
            }.onChange(of: isPopupDisplayed) { newValue in
                if newValue {
                    isPlaying = false
                } else {
                    isPlaying = true
                }
            }
            .frame(height: 25)
            .padding()
            .background(.black)
            .cornerRadius(70)
    }
}

struct TimerView: View {
    
    @Binding var timerString: String
    @Binding var isRestart: Bool
    @Binding var isPlaying: Bool
    @Binding var lastTime: Date // Assuming this is correctly updated elsewhere
    @State private var lastTimeInterval: TimeInterval = 0
    @State private var timer: Timer? // Use the built-in Timer
    @State private var diff: Double = 0.0
    
    var body: some View {
        Text(self.timerString)
            .font(Font.system(.subheadline, design: .monospaced))
            .foregroundColor(.white)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    startTimer()
                }
            }
            .onChange(of: isPlaying) { playing in
                if playing {
                    diff = lastTime.timeIntervalSince1970 - Date().timeIntervalSince1970
                    startTimer()
                } else {
                    timer?.invalidate()
                }
            }
            .onChange(of: isRestart) { restart in
                if restart {
                    restartTimer()
                    isRestart = false // Reset the restart flag
                }
            }
    }
    
    func startTimer() {
        if timer == nil || !timer!.isValid {
            timer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { _ in
                let currentTime = Date().addingTimeInterval(diff)
                let elapsedTime = currentTime.timeIntervalSince(lastTime)
                lastTimeInterval += elapsedTime
                self.timerString = formatTime(lastTimeInterval)
                lastTime = currentTime // Update the last recorded time
            }
        }
    }
    
    func restartTimer() {
        timer?.invalidate() // Stop the current timer
        lastTimeInterval = 0 // Reset the timer interval
        timerString = "00:00" // Reset the displayed time
        diff = 0.0
        startTimer() // Start the timer again
    }
    
    func formatTime(_ timeInterval: TimeInterval) -> String {
        let totalSeconds = Int(timeInterval)
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}


@available(macOS 10.15, *)
public func TimerPublisher(every: CGFloat) -> Publishers.Autoconnect<Timer.TimerPublisher> {
    Timer.publish(every: every, on: .main, in: .common).autoconnect()
}

@available(macOS 10.15, *)
public extension Publishers.Autoconnect where Upstream == Timer.TimerPublisher {
    func stopTimerPublisher() {
        self.upstream.connect().cancel()
    }
}
