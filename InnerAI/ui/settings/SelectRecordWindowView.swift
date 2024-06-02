//
//  SelectRecordWindowView.swift
//  InnerAI
//
//  Created by Bassam Fouad on 28/04/2024.
//

import SwiftUI
import ScreenCaptureKit
import PopupView

struct SelectRecordWindowView: View {
    
    let excluded = ["Item", "statusBarItem", "Menubar", "Dock", "WiFi", "BentoBox", "Clock", "Wallpaper-", "Desktop", "Battery", "StatusIndicator", "AudioVideoModule", "WindowServer", "InnerAIRecordWindow", "CameraWindow", "InnerAI"]
    
    @State private var openedWindowList: [OpenedWindowInfo] = []
    @State var showingPopup = false
    @State private var isHover = false
    @State private var hoveredItemId: CGWindowID = 0
    
    @EnvironmentObject var appDelegate: AppDelegate
    var onSelectedWindow: (_ windowInfo: OpenedWindowInfo) -> Void
    let screenSize = NSScreen.main?.frame.size ?? .zero
    
    var body: some View {
        
        ZStack {}
            .frame(width: screenSize.width, height: screenSize.height, alignment: .center)
            .background(Color.black.opacity(0.6))
            .onAppear {
                showingPopup = true
            }
            .popup(isPresented: $showingPopup) {
                //show this bottom to top animation
                VStack {
                    
                    HStack() {
                        Text("Select a window")
                            .font(.system(size: 14))
                            .fixedSize(horizontal: /*@START_MENU_TOKEN@*/true/*@END_MENU_TOKEN@*/, vertical: false)
                            .frame(maxWidth: .infinity)
                            .foregroundColor(.black).padding(.leading, 20)
                        Spacer()
                        Button(action: {
                            showingPopup = false
                        }) {
                            Image(systemName: "xmark")
                                .foregroundColor(.black)
                                .padding(8)
                        }.buttonStyle(.plain)
                    }.padding(.top, 20)
                    
                    VStack {
                        ScrollView(.vertical, showsIndicators: false) {
                            LazyVGrid(columns: [
                                GridItem(.flexible()),
                                GridItem(.flexible()),
                                GridItem(.flexible())
                            ], spacing: 10) {
                                ForEach(openedWindowList, id: \.self) { window in
                                    VStack {
                                        ZStack {
                                            Image(nsImage: window.image)
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: 160, height: 120)
                                                .cornerRadius(12)
                                                .onTapGesture {
                                                    deselectAll()
                                                    selectWindow(withID: window.windowID)
                                                }.onHover { hover in
                                                    hoveredItemId = window.windowID
                                                }
                                        }
                                        .overlay(
                                            window.isHovered ?
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(.appPurple, lineWidth: 10)
                                            : RoundedRectangle(cornerRadius: 12)
                                                .stroke(.white, lineWidth: 10)
                                        )
                                        .background(Color.white)
                                        .cornerRadius(12)
                                        .shadow(color: Color.gray.opacity(0.4), radius: 4, x: 0, y: 2)
                                        
                                        Text(window.title)
                                            .font(.system(size: 12.0, weight: .medium))
                                            .foregroundColor(.gray)
                                            .lineLimit(1)
                                    }
                                    .padding()
                                }
                            }
                            .padding()
                        }
                        .onChange(of: hoveredItemId, perform: { id in
                            for index in openedWindowList.indices {
                                openedWindowList[index].isHovered = false
                            }
                            if let index = openedWindowList.firstIndex(where: { $0.windowID == id }) {
                                openedWindowList[index].isHovered = true
                            }
                        })
                        .onAppear {
                            getOpenedWindowsList()
                        }
                    }
                }
                .background(.white)
                .frame(width: CGFloat(screenSize.width / 2.0), height: CGFloat(screenSize.height / 2.0))
                .cornerRadius(12)
                .shadow(color: Color.gray.opacity(0.4), radius: 4, x: 0, y: 2)
                .transition(.move(edge: .bottom))
            } customize: {
                $0.type(.floater()).position(.center).animation(.spring()).dismissCallback {
                    appDelegate.hideWindow()
                }
            }
    }
    
    func deselectAll() {
        for index in openedWindowList.indices {
            openedWindowList[index].isSelected = false
        }
    }
    
    func selectWindow(withID windowID: CGWindowID) {
        if let index = openedWindowList.firstIndex(where: { $0.windowID == windowID }) {
            onSelectedWindow(openedWindowList[index])
            openedWindowList[index].isSelected = true
            self.showingPopup = false
        }
    }
    
    func getScreenshotsOfOpenWindows() {
        let options: CGWindowListOption = .optionOnScreenOnly
        let windowListInfo = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: AnyObject]]
        let visibleWindows = windowListInfo?.filter { $0["kCGWindowLayer"] as! Int == 0 }
        visibleWindows?.forEach { windowInfo in
            if let windowID = windowInfo[kCGWindowNumber as String] as? CGWindowID, let title = windowInfo[kCGWindowOwnerName as String] as? String,
               let windowImage = CGWindowListCreateImage(.null, .optionIncludingWindow, windowID, .boundsIgnoreFraming) {
                let image = NSImage(cgImage: windowImage, size: NSSize(width: windowImage.width, height: windowImage.height))
                self.openedWindowList.append(OpenedWindowInfo(windowID: windowID, title: title, image: image))
            }
        }
    }
    
    private func getOpenedWindowsList() {
        SCShareableContent.getExcludingDesktopWindows(true, onScreenWindowsOnly: true, completionHandler: { shareableContent, error in
            if let error = error {
                print("Error retrieving windows: \(error.localizedDescription)")
                return
            }
            
            guard let shareableContent = shareableContent else {
                print("Error: Shareable content is nil")
                return
            }
            
            DispatchQueue.main.async {
                shareableContent.windows.forEach { window in
                    guard window.frame.width >= 500,
                          let windowImage = CGWindowListCreateImage(.null, .optionIncludingWindow, window.windowID, .boundsIgnoreFraming),
                          let title = window.title,
                          !title.isEmpty,
                          !excluded.contains(title),
                          !title.contains("Item-")
                    else {
                        return
                    }
                    let image = NSImage(cgImage: windowImage, size: NSSize(width: windowImage.width, height: windowImage.height))
                    openedWindowList.append(OpenedWindowInfo(windowID: window.windowID, title: title, image: image))
                }
            }
        })
    }
}
