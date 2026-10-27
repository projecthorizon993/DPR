//
//  StylePickerView.swift
//  CameraApp
//
//  Bottom sheet for selecting photo style / color profile.
//

import SwiftUI

struct StylePickerView: View {
    @Binding var selectedStyle: CameraStyle
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            List {
                ForEach(CameraStyle.allCases, id: \.self) { style in
                    StyleRow(style: style, isSelected: selectedStyle == style) {
                        selectedStyle = style
                    }
                }
            }
            .navigationTitle("Photo Style")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct StyleRow: View {
    let style: CameraStyle
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        HStack {
            Button(action: action) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .accentColor : .gray)
            }
            .buttonStyle(PlainButtonStyle())

            VStack(alignment: .leading, spacing: 2) {
                Text(style.displayName)
                    .font(.system(size: 17, weight: .semibold))
                Text(styleDescription(style))
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundColor(.accentColor)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { action() }
    }

    private func styleDescription(_ style: CameraStyle) -> String {
        switch style {
        case .natural: return "Default iPhone color science"
        case .xiaomi: return "Warm, vivid — Xiaomi-inspired"
        case .oppo: return "Cool, crisp — OPPO-inspired"
        case .vivo: return "Soft portrait — Vivo-inspired"
        }
    }
}

struct StylePickerView_Previews: PreviewProvider {
    static var previews: some View {
        StylePickerView(selectedStyle: .constant(.natural))
    }
}
