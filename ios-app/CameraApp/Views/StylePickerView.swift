//
//  StylePickerView.swift
//  JustRaw
//
//  色彩风格选择器 - Xiaomi MIUI Camera风格
//  黑色背景，琥珀色选中状态 (#FFFFCE16)
//

import SwiftUI

struct StylePickerView: View {
    @Binding var selectedStyle: CameraStyle
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // ── Header ──
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                    }

                    Spacer()

                    Text("色彩风格")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)

                    Spacer()

                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                            .frame(width: 44, height: 44)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)

                Divider().background(Color.white.opacity(0.2))

                // ── Style list ──
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(CameraStyle.allCases, id: \.self) { style in
                            StyleRow(
                                style: style,
                                isSelected: selectedStyle == style
                            ) {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    selectedStyle = style
                                }
                            }
                        }
                    }
                    .padding(.vertical, 12)
                }

                Spacer(minLength: 0)
            }
        }
    }
}

struct StyleRow: View {
    let style: CameraStyle
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                // Style accent dot + name
                HStack(spacing: 10) {
                    Circle()
                        .fill(style.accentColor)
                        .frame(width: 12, height: 12)

                    Text(style.displayName)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)

                    Spacer()
                }

                // Selected indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(Color(hex: "FFFFCE16"))
                } else {
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        .frame(width: 22, height: 22)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 0)
                    .fill(isSelected ? Color.white.opacity(0.08) : Color.black)
            )
            .overlay(
                // Bottom separator
                VStack {
                    Spacer()
                    Rectangle()
                        .fill(Color.white.opacity(0.12))
                        .frame(height: 1)
                }
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct StylePickerView_Previews: PreviewProvider {
    static var previews: some View {
        StylePickerView(selectedStyle: .constant(.natural))
    }
}
