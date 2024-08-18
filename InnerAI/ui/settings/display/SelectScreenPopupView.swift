//
//  SelectDisplayPopupView.swift
//  InnerAI
//
//  Created by Bassam Fouad on 14/08/2024.
//

import SwiftUI
import ScreenCaptureKit
import PopupView
import Cocoa
import CoreGraphics
import IOKit.graphics

struct SelectScreenPopupView: View {
    
    let excluded = ["Item", "statusBarItem", "Menubar", "Dock", "WiFi", "BentoBox", "Clock", "Wallpaper-", "Desktop", "Battery", "StatusIndicator", "AudioVideoModule", "WindowServer", "InnerAIRecordWindow", "CameraWindow", "InnerAI", "Notification Center"]
    
    @State private var screenList: [ScreenInfo] = []
    @State var showingPopup = false
    @State private var isHover = false
    @State private var hoveredItemId: CGWindowID = 0
    
    @EnvironmentObject var appDelegate: AppDelegate
    var didScreenSelection: (_ windowInfo: ScreenInfo) -> Void
    var screenSize: CGRect
    
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
                        Text("Select a Screen")
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
                                ForEach(screenList, id: \.self) { screen in
                                    VStack {
                                        ZStack {
                                            Image(nsImage: screen.image)
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: 160, height: 120)
                                                .cornerRadius(12)
                                                .onTapGesture {
                                                    deselectAll()
                                                    selectScreen(withID: screen.displayID)
                                                }.onHover { hover in
                                                    hoveredItemId = screen.displayID
                                                }
                                        }
                                        .overlay(
                                            screen.isHovered ?
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(.appPurple, lineWidth: 10)
                                            : RoundedRectangle(cornerRadius: 12)
                                                .stroke(.white, lineWidth: 10)
                                        )
                                        .background(Color.white)
                                        .cornerRadius(12)
                                        .shadow(color: Color.gray.opacity(0.4), radius: 4, x: 0, y: 2)
                                        
                                        Text(screen.title)
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
                            for index in screenList.indices {
                                screenList[index].isHovered = false
                            }
                            if let index = screenList.firstIndex(where: { $0.displayID == id }) {
                                screenList[index].isHovered = true
                            }
                        })
                        .onAppear {
                            getDisplayList()
                        }
                    }
                }
                .background(.white)
                .frame(width: CGFloat(screenSize.width / 2.0), height: 240.0)
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
        for index in screenList.indices {
            screenList[index].isSelected = false
        }
    }
    
    func selectScreen(withID displayId: CGDirectDisplayID) {
        if let index = screenList.firstIndex(where: { $0.displayID == displayId }) {
            didScreenSelection(screenList[index])
            screenList[index].isSelected = true
            self.showingPopup = false
        }
    }
    
    func captureDisplaysAndSaveToDocuments(screens: [(CGDirectDisplayID, CGRect)]) -> [ScreenInfo]? {
        var capturedScreens: [ScreenInfo] = []
        
        for (index, screen) in screens.enumerated() {
            var rect = CGDisplayBounds(screen.0)
            
            guard let colorSpace = CGColorSpace(name: CGColorSpace.genericRGBLinear) else {
                print("Failed to create colorspace")
                return nil
            }
            
            guard let cgContext = CGContext(data: nil,
                                            width: Int(rect.width),
                                            height: Int(rect.height),
                                            bitsPerComponent: 8,
                                            bytesPerRow: 0,
                                            space: colorSpace,
                                            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue) else {
                print("Failed to create bitmap context")
                return nil
            }
            
            cgContext.clear(CGRect(x: 0, y: 0, width: rect.width, height: rect.height))
            
            guard let image = CGDisplayCreateImage(screen.0) else {
                continue
            }
            
            let dest = CGRect(x: 0, y: 0, width: rect.width, height: rect.height)
            cgContext.draw(image, in: dest)
            
            guard let finalImage = cgContext.makeImage() else {
                print("Failed to create image from bitmap context")
                return nil
            }
            
            // Save to Documents directory with a unique filename
            let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let fileURL = documentsDirectory.appendingPathComponent("screenshot_\(index + 1).png")
            
            guard let destination = CGImageDestinationCreateWithURL(fileURL as CFURL, kUTTypePNG, 1, nil) else {
                print("Failed to create image destination")
                return nil
            }
            
            CGImageDestinationAddImage(destination, finalImage, nil)
            
            if !CGImageDestinationFinalize(destination) {
                print("Failed to finalize image destination")
                return nil
            }
            
            guard let uiImage = NSImage(contentsOf: fileURL) else { return  capturedScreens }
            capturedScreens.append(ScreenInfo(displayID: screen.0, displaySize: DisplaySize(width: screen.1.width, height: screen.1.height), title: "Screen \(index + 1)", image: uiImage))
        }
        
        return capturedScreens
    }
    
    private func getDisplayList() {
        SCShareableContent.getWithCompletionHandler({ shareableContent, error in
            if let error = error {
                print("Error retrieving windows: \(error.localizedDescription)")
                return
            }
            
            guard let shareableContent = shareableContent else {
                print("Error: Shareable content is nil")
                return
            }
            
            DispatchQueue.main.async {
                shareableContent.displays.forEach {
                    print("SCREENSIZE: \($0.width), \($0.height)")
                }
                if let screens = captureDisplaysAndSaveToDocuments(screens: shareableContent.displays.map { ($0.displayID, $0.frame) }) {
                    self.screenList = screens
                }
            }
        })
    }
}

