//
//  CustomPopupView.swift
//  InnerAI
//
//  Created by Bassam Fouad on 28/04/2024.
//

import SwiftUI
import PopupView

enum PopupActionType {
    case action
    case dismiss
    case takeMeBack
}

struct CustomPopupView: View {
    
    let title: String
    let buttonTile: String
    let message: String
    let onClick: (_ action: PopupActionType) -> Void
    
    @State var showingPopup = false
    
    var body: some View {
        
        VStack {}
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.opacity(0.6))
            .onAppear {
                showingPopup = true
            }.popup(isPresented: $showingPopup) {
                
                ZStack {
                    
                 RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white)
                                    .frame(width: 530, height: 300)
                                    .shadow(color: Color.gray.opacity(0.4), radius: 4, x: 0, y: 2)
                    
                    //show this bottom to top animation
                    VStack(spacing: 10) {
                        
                        HStack {
                            Spacer()
                            Text(title)
                                .font(.system(size: 24))
                                .fontWeight(.semibold)
                                .foregroundColor(.black)
                            Spacer()
                            Button(action: {
                                showingPopup = false
                            }) {
                                Image(systemName: "xmark")
                                    .foregroundColor(.appPurple)
                                    .padding(8)
                            }.buttonStyle(.plain).padding(.trailing, 10)
                        }
                        
                        Text(message)
                            .font(.system(size: 14))
                            .fontWeight(.light)
                            .foregroundColor(.black)
                            .multilineTextAlignment(.center)
                            .padding()
                        
                        Button(action: {
                            showingPopup = false
                        }) {
                            Text("No, take me back")
                                .font(.system(size: 16))
                                .fontWeight(.semibold)
                                .foregroundColor(.appPurple)
                        }.buttonStyle(BorderlessButtonStyle())
                        
                        Button(action: {
                            onClick(.action)
                        }) {
                            Text(buttonTile)
                                .fontWeight(.semibold)
                                .font(.title2)
                                .frame(maxWidth: .infinity, maxHeight: 20)
                                .padding()
                                .foregroundColor(.white)
                                .background(.appPurple)
                                .cornerRadius(12)
                        }.buttonStyle(BorderlessButtonStyle()).frame(maxWidth: 232)
                            .padding(10)
                        
                    }
                    .background(.white)
                    .frame(maxWidth: 530)
                    .transition(.move(edge: .bottom))
                }
                
            } customize: {
                $0.type(.floater()).position(.center).animation(.spring()).dismissCallback {
                    onClick(.takeMeBack)
                }
            }
    }
}
