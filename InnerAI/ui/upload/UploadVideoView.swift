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

    var body: some View {
            
            VStack(spacing: 20) {
                Text("Uploading Video")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.black)
                
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
                    CircularProgressWithText(progress: $viewModel.progressPercentage)
                }
                
                uploadCompletionText
                
                if !viewModel.showErrorState && !viewModel.showSuccessState {
                    Button(action: {
                        displayCancelUploadPopup()
                    }) {
                        Text("Cancel Upload")
                            .font(.system(size: 12))
                            .fontWeight(.semibold)
                            .foregroundColor(.gray)
                    }.buttonStyle(BorderlessButtonStyle())
                }
                
                if viewModel.showErrorState {
                    Image("sad-face")
                        .resizable()
                        .frame(width: 80, height: 80) // Adjust size as needed
                        .aspectRatio(contentMode: .fill)
                    
                    Text("Unable to upload, server not responding please")
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.gray)
                    
                    Button(action: {
                        viewModel.initUpload()
                    }) {
                        Text("Retry")
                            .font(.system(size: 12))
                            .fontWeight(.semibold)
                            .foregroundColor(.gray)
                    }.buttonStyle(BorderlessButtonStyle())
                }
                
                if viewModel.showErrorState {
                    Button(action: {
                        appDelegate.displayRecordSettingsView()
                    }) {
                        Text("Back to recored settings")
                            .font(.system(size: 12))
                            .fontWeight(.semibold)
                            .foregroundColor(.purple)
                    }.buttonStyle(BorderlessButtonStyle())
                }
            }
            .onAppear {
                viewModel.initUpload()
            }
            .onChange(of: viewModel.uploadedVideoUrl, perform: { url in
                if !url.isEmpty {
                    openURLInDefaultBrowser(url)
                    appDelegate.displayRecordSettingsView()
                }
            })
            .frame(width: 280, height: 320)
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
    
    private var uploadStatusText: some View {
            Text("We are uploading your recording to Inner AI's Library.")
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.center)
                .font(.system(size: 14))
                .fontWeight(.light)
                .foregroundColor(.gray)
        }
        
    private var uploadCompletionText: some View {
        Text("Your video will be ready in moments.")
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
            .multilineTextAlignment(.center)
            .font(.system(size: 14))
            .fontWeight(.light)
            .foregroundColor(.gray)
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
