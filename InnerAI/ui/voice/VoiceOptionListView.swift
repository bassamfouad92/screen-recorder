//
//  VoiceOptionListView.swift
//  InnerAI
//
//  Created by Bassam Fouad on 05/05/2024.
//

import SwiftUI

struct VoiceOptionListView: View {
    @State var options: [any SelectableOption] = []
    
    var didSelectVoiceOption: (VoiceOption) -> Void
    
    var body: some View {
        VStack(spacing: 10) {
                                    
            HStack {
                Text("Choose Microphone")
                    .frame(width: 240)
                    .font(.system(size: 14))
                    .foregroundColor(.black)
                    .multilineTextAlignment(.center)
            }
            
            VStack(spacing: 10) {
                ForEach(options.indices, id: \.self) { index in
                    let optionBinding = $options[index]
                     SettingOptionView(model: optionBinding, isSubOption: true, OnSelected: {}, onTap: {
                        if let option = optionBinding.wrappedValue as? VoiceOption {
                            didSelectVoiceOption(option)
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
