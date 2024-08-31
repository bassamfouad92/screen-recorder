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
    
    @State private var showTooltip = false
    @State private var showFinishTooltip = false
    @State private var showPlayPauseTooltip = false
    @State private var showRestartTooltip = false
    @State private var showDeleteTooltip = false

    var body: some View {
         VStack(spacing: 0) {
             if showTooltip {
                 LazyHStack(spacing: 10) {
                     Text("     ").frame(width: 24, height: 0.5).overlay {
                         TooltipView(
                             alignment: .top,
                             isVisible: $showFinishTooltip
                         ) {
                             Text("Finish")
                                 .frame(height: 20)
                         }
                     }
                     Text("     ").frame(maxHeight: 0.5)
                     Text("   ").frame(maxHeight: 0.5)
                     Text("     ").frame(width: 24, height: 0.5).overlay {
                         TooltipView(
                             alignment: .top,
                             isVisible: $showPlayPauseTooltip
                         ) {
                             Text(isPlaying ? "Pause" : "Resume")
                                 .frame(height: 20)
                         }
                     }
                     Image("line")
                         .resizable()
                         .frame(width: 2, height: 0.5).tint(.clear)
                     Text("     ").frame(width: 24, height: 0.5).overlay {
                         TooltipView(
                             alignment: .top,
                             isVisible: $showRestartTooltip
                         ) {
                             Text("Restart")
                                 .frame(height: 20)
                         }
                     }
                     Text("     ").frame(width: 24, height: 0.5).overlay {
                         TooltipView(
                             alignment: .top,
                             isVisible: $showDeleteTooltip
                         ) {
                             Text("Delete")
                                 .frame(height: 20)
                         }
                     }
                     Text(" ")
                         .frame(width: 24, height: 0.5)
                 }.frame(maxHeight: 0.5).background(.clear)
             }
            LazyHStack(spacing: 10) {
                Button(action: {
                    onClicked(.stop)
                }) {
                    Image("stop_icon")
                        .resizable()
                        .frame(width: 24, height: 24)
                }.buttonStyle(.plain).onHover { hovering in
                    showTooltip = hovering
                    showFinishTooltip = hovering
                }
                TimerView(timerString: $timerString, isRestart: $restartRecording, isPlaying: $isPlaying, lastTime: $lastTime)
                if isPlaying {
                    Button(action: {
                        isPlaying = false
                        onClicked(.pause)
                    }) {
                        Image("pause_icon")
                            .resizable()
                            .frame(width: 24, height: 24)
                    }.buttonStyle(.plain).onHover { hovering in
                        showTooltip = hovering
                        showPlayPauseTooltip = hovering
                    }
                } else {
                    Button(action: {
                        isPlaying = true
                        onClicked(.resume)
                    }) {
                        Image("play_icon")
                            .resizable()
                            .frame(width: 24, height: 24)
                    }.buttonStyle(.plain).onHover { hovering in
                        showTooltip = hovering
                        showPlayPauseTooltip = hovering
                    }
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
                }.buttonStyle(.plain).onHover { hovering in
                    showTooltip = hovering
                    showRestartTooltip = hovering
                }
                Button(action: {
                    onClicked(.delete)
                }) {
                    Image("delete_icon")
                        .resizable()
                        .frame(width: 24, height: 24)
                }.buttonStyle(.plain).onHover { hovering in
                    showTooltip = hovering
                    showDeleteTooltip = hovering
                }
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

struct TooltipView<Content: View>: View {
    let alignment: Edge
    @Binding var isVisible: Bool
    let content: () -> Content
    let arrowOffset = CGFloat(8)

    private var oppositeAlignment: Alignment {
        let result: Alignment
        switch alignment {
        case .top: result = .bottom
        case .bottom: result = .top
        case .leading: result = .trailing
        case .trailing: result = .leading
        }
        return result
    }

    private var theHint: some View {
        content()
            .padding()
            .background(Color.black)
            .foregroundColor(.white)
            .cornerRadius(8)
            .background(alignment: oppositeAlignment) {

                // The arrow is a square that is rotated by 45 degrees
                Rectangle()
                    .fill(Color.black)
                    .frame(width: 15, height: 15)
                    .rotationEffect(.degrees(45))
                    .offset(x: alignment == .leading ? arrowOffset : 0)
                    .offset(x: alignment == .trailing ? -arrowOffset : 0)
                    .offset(y: alignment == .top ? arrowOffset : 0)
                    .offset(y: alignment == .bottom ? -arrowOffset : 0)
            }
            .padding()
            .fixedSize()
    }

    var body: some View {
        if isVisible {
            GeometryReader { proxy1 in

                // Use a hidden version of the hint to form the footprint
                theHint
                    .hidden()
                    .overlay {
                        GeometryReader { proxy2 in

                            // The visible version of the hint
                            theHint
                                .drawingGroup()
                                .shadow(radius: 4)

                                // Center the hint over the source view
                                .offset(
                                    x: -(proxy2.size.width / 2) + (proxy1.size.width / 2),
                                    y: -(proxy2.size.height / 2) + (proxy1.size.height / 2)
                                )
                                // Move the hint to the required edge
                                .offset(x: alignment == .leading ? (-proxy2.size.width / 2) - (proxy1.size.width / 2) : 0)
                                .offset(x: alignment == .trailing ? (proxy2.size.width / 2) + (proxy1.size.width / 2) : 0)
                                .offset(y: alignment == .top ? (-proxy2.size.height / 2) - (proxy1.size.height / 2) : 0)
                                .offset(y: alignment == .bottom ? (proxy2.size.height / 2) + (proxy1.size.height / 2) : 0)
                        }
                    }
            }
            .onTapGesture {
                isVisible.toggle()
            }
        }
    }
}
