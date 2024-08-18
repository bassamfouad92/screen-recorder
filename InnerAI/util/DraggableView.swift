//
//  DraggableView.swift
//  InnerAI
//
//  Created by Bassam Fouad on 04/05/2024.
//

import SwiftUI

struct DraggableView<Content: View>: View {
    
    var screenSize: CGRect
    var content: Content

    @State var offset = CGSize.zero
    @State private var finalOffset = CGSize.zero // To store the final offset after dragging
    var onDragging: (_ offset: CGSize) -> Void?
    var contentSize: CGSize?
    var specificWindowSize: CGSize?

    init(@ViewBuilder content: () -> Content, callback: @escaping (_ offset: CGSize) -> Void?, contentSize: CGSize = .zero, specificWindowSize: CGSize? = nil, screenSize: CGRect) {
        self.content = content()
        self.onDragging = callback
        self.contentSize = contentSize
        self.specificWindowSize = specificWindowSize
        self.screenSize = screenSize
    }
    
    var body: some View {
            content
            .foregroundColor(.blue)
            .offset(x: offset.width, y: offset.height)
            .gesture(
                DragGesture()
                    .onChanged { gesture in
                        let newOffset = CGSize(width: self.finalOffset.width + gesture.translation.width,
                                               height: self.finalOffset.height + gesture.translation.height)
                        
                        let width = (self.contentSize?.width ?? 190)
                        let height = (self.contentSize?.height ?? 190)

                        // Calculate the maximum allowed offset based on screen size
                        let maxX = self.screenSize.width - (self.contentSize?.width ?? 190) * (width >= 200 ? 1.15 : 1.0)
                        let maxY = self.screenSize.height - height * 2.1
                                                
                        if newOffset.width < -5 || newOffset.height >= (height >= 100 ? height / 1.8 : height) {
                            return
                        }
                        
                        if let windowSize = specificWindowSize {
                            if newOffset.height < -(windowSize.height - 40) || newOffset.width >= (maxX - windowSize.width) {
                                return
                            }
                        }
                        
                        // Limit the new offset within the bounds
                        let limitedOffset = CGSize(
                            width: min(maxX, max(-maxX, newOffset.width)),
                            height: min(maxY, max(-maxY, newOffset.height))
                        )
                        
                        self.offset = limitedOffset
                        onDragging(offset)
                    }
                    .onEnded { gesture in
                        // Save the final offset after drag ends
                        self.finalOffset = self.offset
                        print(self.offset)
                    }
            )
    }
}
