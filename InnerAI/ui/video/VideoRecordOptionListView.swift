//
//  VideoRecordOptionListView.swift
//  InnerAI
//
//  Created by Bassam Fouad on 01/05/2024.
//

import SwiftUI

struct VideoRecordOptionListView: View {
    
    @State var options: [any SelectableOption] = []
    
    var didSelectVideoOption: (VideoOption) -> Void
    
    var body: some View {
        VStack(spacing: 10) {
                                    
            HStack {
                Text("What to Record?")
                    .frame(width: 240)
                    .font(.system(size: 14))
                    .foregroundColor(.black)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 10) {
                ForEach(options.indices, id: \.self) { index in
                    let optionBinding = $options[index]
                     SettingOptionView(model: optionBinding, isSubOption: true, OnSelected: {}, onTap: {
                        if let videoOption = optionBinding.wrappedValue as? VideoOption {
                                didSelectVideoOption(videoOption)
                        }
                    })
                }
            }
        }
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
