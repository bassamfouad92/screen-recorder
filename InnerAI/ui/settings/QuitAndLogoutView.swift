//
//  QuitAndLogoutView.swift
//  InnerAI
//
//  Created by Bassam Fouad on 12/05/2024.
//

import SwiftUI

struct QuitAndLogoutView: View {
    
    @State private var logoutOption: any SelectableOption = Option(title: "Logout", icon: "logout", rightIcon: .check, isSelected: false)
    
    @State private var quitOption: any SelectableOption = Option(title: "Quit", icon: "power_off", rightIcon: .check, isSelected: false)

    var showLogoutOption: Bool = true
    var onLogout: () -> Void
            
    var body: some View {
        VStack(spacing: 10.0) {
            
            if showLogoutOption {
                SettingOptionView(model: $logoutOption, OnSelected: {}, onTap: {
                    onLogout()
                }).padding(5.0)
            }
            
            SettingOptionView(model: $quitOption, OnSelected: {}, onTap: {
                NSApp.terminate(nil) // Quit the application
            }).padding(5.0)
            
        }
        .frame(width: 250)
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
}
