import SwiftUI

/// Variant picker — shows per-variant options within the selected style.
/// Each variant has its own color matrix, gamma curve, LUT, and watermark config.
struct VariantPickerView: View {
    @Binding var selectedVariant: CameraStyleVariant
    @Environment(\.dismiss) private var dismiss

    /// Current style derived from the selected variant.
    private var currentStyle: CameraStyle {
        switch selectedVariant {
        case .naturalStandard: return .natural
        case .leicaStandard, .leica100th, .leicaAuthentic, .leicaM10R, .leicaM3, .leicaM9:
            return .xiaomi
        case .hasselbladNatural, .hasselbladWorld, .hasselbladStore:
            return .oppo
        case .zeissNatural, .zeissCinematic, .zeissSoftFocus, .zeissStarLight,
             .zeissBiotar, .zeissDistagon, .zeissPlanar, .zeissSonnar:
            return .vivo
        }
    }

    /// Variants available for the current style.
    private var availableVariants: [CameraStyleVariant] {
        CameraStyleVariant.variants(for: currentStyle)
    }

    var body: some View {
        NavigationView {
            Form {
                Section("\(currentStyle.title) Variants") {
                    ForEach(availableVariants, id: \.self) { variant in
                        Button {
                            selectedVariant = variant
                        } label: {
                            HStack {
                                ZStack {
                                    Circle()
                                        .fill(variant.accentColor)
                                        .frame(width: 24, height: 24)
                                    Text(variant.initials)
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                                .frame(width: 36, height: 36)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(variant.title)
                                        .font(.body)
                                    Text(variantMatrixDescription(for: variant))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                if selectedVariant == variant {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }

                Section("Variant Info") {
                    HStack {
                        Text("Variant")
                        Spacer()
                        Text(selectedVariant.title)
                    }
                    HStack {
                        Text("Color Matrix")
                        Spacer()
                        Text(matrixString(for: selectedVariant.colorMatrix))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Gamma")
                        Spacer()
                        Text(String(format: "%.2f", selectedVariant.gamma))
                    }
                    HStack {
                        Text("Watermark")
                        Spacer()
                        Text("\(Int(selectedVariant.watermarkOpacity * 100))% opacity")
                    }
                    HStack {
                        Text("Watermark Margin")
                        Spacer()
                        Text("\(selectedVariant.watermarkMargin)px")
                    }
                }
            }
            .navigationTitle("Variant")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    /// Human-readable matrix description.
    private func matrixString(for matrix: [[Float]]) -> String {
        matrix.map { row in
            row.map { String(format: "%.2f", $0) }.joined(separator: ", ")
        }.joined(separator: " | ")
    }
}

struct VariantPickerView_Previews: PreviewProvider {
    static var previews: some View {
        VariantPickerView(selectedVariant: .constant(.naturalStandard))
    }
}
