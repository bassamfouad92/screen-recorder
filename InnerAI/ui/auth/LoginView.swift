//
//  LoginView.swift
//  InnerAI
//
//  Created by Bassam Fouad on 27/04/2024.
//
import SwiftUI

struct LoginView: View {
    
    @ObservedObject var viewModel: LoginViewModel
    @EnvironmentObject var appDelegate: AppDelegate
    @State private var isPasswordVisible = false
    @State private var showMenu = false
    @State private var isEditing = false
    @State private var isEditingPassword = false

    var body: some View {
            
            VStack(spacing: 20) {
                
                HStack {
                    Spacer()
                    Text("Login to Continue")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.black)
                    Spacer()
                    Button(action: {
                        showMenu = true
                    }) {
                        Image("menu_icon") // Example system image for menu button
                            .resizable()
                            .frame(width: 30, height: 30)
                            .aspectRatio(contentMode: .fill)
                    }.buttonStyle(PlainButtonStyle())
                }
                
                Text("Enter your Inner AI account to continue.")
                    .font(.system(size: 14))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .foregroundColor(.appDarkgray)
                
                TextField("Email", text: $viewModel.email, onEditingChanged: { editing in
                    isEditing = editing
                })
                .frame(height: 48)
                .foregroundColor(.black)
                .textFieldStyle(PlainTextFieldStyle())
                .tint(.pink)
                .padding([.horizontal], 8)
                .cornerRadius(16)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(isEditing ? .hover : .gray))
                .padding([.horizontal], 0)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.white)
                )
                
                ZStack {
                    if isPasswordVisible {
                        TextField("Password", text: $viewModel.password, onEditingChanged: { editing in
                            isEditingPassword = editing
                        })
                        .frame(height: 48)
                        .foregroundColor(.black)
                        .textFieldStyle(PlainTextFieldStyle())
                        .padding([.horizontal], 8)
                        .padding(.trailing, 40) // Add padding from the right
                        .cornerRadius(16)
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(isEditingPassword ? .hover : .gray))
                        .padding([.horizontal], 0)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.white)
                        )
                    } else {
                        SecureField("Password", text: $viewModel.password)
                        .frame(height: 48)
                        .textFieldStyle(PlainTextFieldStyle())
                        .foregroundColor(.black)
                        .padding([.horizontal], 8)
                        .padding(.trailing, 40) // Add padding from the right
                        .cornerRadius(16)
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(isEditingPassword ? .hover : .gray))
                        .padding([.horizontal], 0)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(.white)
                        )
                    }
                    
                    Button(action: {
                        isPasswordVisible.toggle()
                    }) {
                        Image(systemName: isPasswordVisible ? "eye" : "eye.slash")
                            .padding(.trailing, 8)
                            .foregroundColor(.appPurple)
                    }
                    .buttonStyle(BorderlessButtonStyle()).offset(x: 100)
                }
                
                Button(action: {
                    // Action for forgot password
                }) {
                    Text("Forgot your password?")
                        .font(.system(size: 12))
                        .fontWeight(.bold)
                        .foregroundColor(.appDarkgray)
                }.buttonStyle(BorderlessButtonStyle())
                
                Button(action: {
                    if !viewModel.isLoading {
                        viewModel.login()
                    }
                }) {
                    if viewModel.isLoading {
                        ProgressView()

                    } else {
                        Text("Login")
                            .fontWeight(.semibold)
                            .font(.title2)
                            .frame(maxWidth: .infinity, maxHeight: 20)
                            .padding()
                            .foregroundColor(.white)
                            .background(viewModel.enableLoginButton ? .appPurple : .appPurple.opacity(0.6))
                            .cornerRadius(12)
                    }
                }.buttonStyle(BorderlessButtonStyle())
                
                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .fixedSize(horizontal: /*@START_MENU_TOKEN@*/true/*@END_MENU_TOKEN@*/, vertical: false)
                }
                
                HStack {
                    Text("Don't have an account?")
                        .foregroundColor(.appDarkgray)
                    Button(action: {
                        // Action for Sign Up
                    }) {
                        Text("Sign Up")
                            .foregroundColor(.appPurple)
                            .underline()
                    }.buttonStyle(BorderlessButtonStyle()).offset(x: -5)
                }
            }
            .onChange(of: viewModel.isLoggedIn) { loggedIn in
                if loggedIn {
                    appDelegate.displayRecordSettingsView()
                }
            }
            .frame(width: 260, height: 380)
            .padding()
            .textFieldStyle(.roundedBorder)
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
            .popover(isPresented: $showMenu, attachmentAnchor: showMenu ? .point(.top) : .point(.leading), arrowEdge: .leading) {
                 QuitAndLogoutView(showLogoutOption: false, onLogout: {})
            }
    }
}
