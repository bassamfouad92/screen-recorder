//
//  UploadVideoView.swift
//  InnerAI
//
//  Created by Bassam Fouad on 05/05/2024.
//

import SwiftUI

struct UploadVideoView: View {
    
    @ObservedObject var viewModel: UploadViewModel
    @EnvironmentObject var appDelegate: AppDelegate
    @State private var settingsViewType: SettingsViewType = .none

    var body: some View {
            
         VStack(spacing: 10) {
                
                if viewModel.showErrorState {
                    HStack {
                        Image("logo")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .scaleEffect(0.3)
                            .padding(.leading, 30)
                        
                        Button(action: {
                            if settingsViewType == .quit {
                                settingsViewType = .none
                            } else {
                                settingsViewType = .quit
                            }
                        }) {
                            Image("menu_icon") // Example system image for menu button
                                .resizable()
                                .frame(width: 30, height: 30)
                                .aspectRatio(contentMode: .fill)
                                .background(.clear)
                        }.buttonStyle(PlainButtonStyle())
                    }
                }
                
                if !viewModel.showErrorState {
                    Text("Uploading Video")
                        .font(.custom("DMSans-Bold", size: 18))
                        .foregroundColor(.black)
                }
                
                uploadStatusText
                
                if viewModel.isLoading {
                    ProgressView()
                    Text("Initiating video upload..")
                        .multilineTextAlignment(.center)
                        .font(.system(size: 14))
                        .fontWeight(.light)
                        .foregroundColor(.gray)
                }
                
                if !viewModel.isLoading && !viewModel.showErrorState {
                    CircularProgressWithText(progress: $viewModel.progressPercentage).padding(.top, 20)
                }
                
                uploadCompletionText
                
                if !viewModel.showErrorState && !viewModel.showSuccessState {
                    Button(action: {
                        displayCancelUploadPopup()
                    }) {
                        Text("Cancel Upload")
                            .font(.custom("DMSans-Medium", size: 12))
                            .foregroundColor(.gray)
                    }.buttonStyle(BorderlessButtonStyle()).padding(.top, 20)
                }
                
                if viewModel.showErrorState {
                    
                    Image("sad-face")
                        .resizable()
                        .frame(width: 125, height: 102)
                        .background(Color.clear)
                        .padding(.leading, 40)
                    
                    VStack(spacing: 4) {
                        Button(action: {
                            viewModel.initUpload()
                        }) {
                            Text("Retry")
                                .font(.custom("DMSans-Medium", size: 14))
                                .foregroundColor(.appPurple)
                                .underline()
                        }.buttonStyle(BorderlessButtonStyle())
                        
                        Text("or")
                            .font(.custom("DMSans-Medium", size: 14))
                            .multilineTextAlignment(.center)
                            .foregroundColor(Color(red: 59 / 255, green: 61 / 255, blue: 59 / 255))
                        
                        Button(action: {
                            appDelegate.displayRecordSettingsView()
                        }) {
                            Text("Create New Recording")
                                .font(.custom("DMSans-Medium", size: 14))
                                .foregroundColor(.appPurple)
                                .underline()
                        }.buttonStyle(BorderlessButtonStyle())
                    }.padding(.top, 20)
                }
            }
            .onAppear {
                viewModel.initUpload()
            }
            .onChange(of: viewModel.uploadedVideoUrl, perform: { url in
                if !url.isEmpty {
                    openURLInDefaultBrowser(url)
                    //copy url to clipboard
                  NSPasteboard.general.declareTypes([.string], owner: nil)
        NSPasteboard.general.setString(url, forType: .string)
                    appDelegate.displayRecordSettingsView()
                }
            })
            .popover(isPresented: .constant(settingsViewType != .none), attachmentAnchor: popoverArrowAlignment(), arrowEdge: .leading) {
                VStack {
                    switch settingsViewType {
                    case .quit:
                        QuitAndLogoutView(onLogout: {
                            UserSessionManager.logout()
                            appDelegate.hideWindow()
                            appDelegate.displayLoginView()
                        })
                    default:
                        EmptyView()
                    }}
            }
            .frame(width: 271, height: 387)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                .backGradientOne,
                                .backGradientTwo,
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    ).padding(EdgeInsets(top: 5, leading: 5, bottom: 5, trailing: 5))
            )
            .edgesIgnoringSafeArea(.all)
    }
    
    private func openURLInDefaultBrowser(_ urlString: String) {
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        } else {
            print("Invalid URL: \(urlString)")
        }
    }
    
    func popoverArrowAlignment() -> PopoverAttachmentAnchor {
        switch settingsViewType {
        case .quit:
            return .rect(.rect(CGRect(x: 271 - 50.0, y: -24, width: 100, height: 100)))
        default:
            return .rect(.rect(CGRect(x: 0, y: 20, width: 100, height: 600)))
        }
    }
    
    private var uploadStatusText: some View {
        Group {
            if viewModel.showErrorState {
                VStack {
                    Text("Oops!\nSomething went wrong")
                        .font(.custom("DMSans-Bold", size: 14))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .foregroundColor(Color(red: 59 / 255, green: 61 / 255, blue: 59 / 255))
                }
            } else {
                Text("We are uploading your\nrecording to Inner AI's Library.")
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.center)
                    .font(.custom("DMSans-Light", size: 14))
                    .foregroundColor(Color(red: 59 / 255, green: 61 / 255, blue: 59 / 255))
            }
        }
    }
        
    private var uploadCompletionText: some View {
        Group {
            if viewModel.showErrorState {
                VStack {
                    Text("Click below to try uploading again or\nstart a new recording.")
                        .font(.custom("DMSans-Medium", size: 14))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .foregroundColor(Color(red: 59 / 255, green: 61 / 255, blue: 59 / 255))
                        .padding(.top, 10)
                }
            } else {
                Text("Your video will be ready\nin moments.")
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.center)
                    .font(.custom("DMSans-Light", size: 14))
                    .foregroundColor(Color(red: 59 / 255, green: 61 / 255, blue: 59 / 255))
                    .padding(.top, 10)
            }
        }
    }
    
    private func displayCancelUploadPopup() {
        appDelegate.showCustomPopup(title: "Cancel Upload", message: "The progress on your current video will be lost.", completion: { isTakeMeBackClicked in
            
            if isTakeMeBackClicked {
                appDelegate.hideCustomPopup()
                return
            }
            viewModel.cancelUpload()
            appDelegate.displayRecordSettingsView()
        })
    }
}
