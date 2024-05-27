//
//  SettingOptionView.swift
//  InnerAI
//
//  Created by Bassam Fouad on 30/04/2024.
//

import SwiftUI

struct SettingOptionView: View {
    
    @Binding var model: any SelectableOption
    @State private var isHover = false
    var isSubOption = false
    var OnSelected: () -> Void
    var onTap: (() -> Void)? = nil
    
    var body: some View {
        HStack {
            // Left image icon
            Image(model.icon)
                .resizable()
                .frame(width: 20, height: 20)
                .padding()
            
            // Label
            Text(model.title)
                .font(.system(size: 14))
                .foregroundColor(.black)
                .lineLimit(1)
                .padding(.leading, 8)
            
            Spacer() // Spacing between label and button
            
            //settings button
            if isHover {
                if model.rightIcon == .settings {
                    Image(model.rightIcon.getIconName())
                        .resizable()
                        .frame(width: model.rightIcon.getIconSize(), height: model.rightIcon.getIconSize())
                        .padding(8)
                }
            } else {
                if model.isSelected {
                    Image(RigthIconType.check.getIconName())
                    .resizable()
                    .frame(width: model.rightIcon.getIconSize(), height: model.rightIcon.getIconSize())
                    .padding(8)
                }
            }
        }
        .frame(maxHeight: 35)
        .padding(EdgeInsets(top: 10.0, leading: 0, bottom: 10.0, trailing: 0))
        .background(model.rightIcon == .check && model.isSelected ? .appLightPurple : Color.white)
        .cornerRadius(12)
        .shadow(color: Color.gray.opacity(0.6), radius: 8, x: 0, y: 4)
        .overlay( /// apply a rounded border
            isHover ?
            RoundedRectangle(cornerRadius: 12).stroke(isSubOption ? .appPurple: .hover, lineWidth: 2) : nil
        )
        .onTapGesture {
            onTap?()
        }.onHover { over in
            isHover = over
        }
    }
}
