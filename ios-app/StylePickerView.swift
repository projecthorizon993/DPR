//
//  StylePickerView.swift
//  CameraApp
//

import SwiftUI

struct StylePickerView: View {
    @Binding var selectedStyle: CameraStyle

    var body: some View {
        NavigationView {
            List(CameraStyle.allCases, id: \.self) { style in
                HStack {
                    Circle()
                        .fill(style.accentColor)
                        .frame(width: 12, height: 12)
                    Text(style.displayName)
                        .foregroundColor(.white)
                    Spacer()
                    if selectedStyle == style {
                        Image(systemName: "checkmark")
                            .foregroundColor(style.accentColor)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedStyle = style
                }
            }
            .navigationTitle("Style")
            .preferredColorScheme(.dark)
        }
    }
}
