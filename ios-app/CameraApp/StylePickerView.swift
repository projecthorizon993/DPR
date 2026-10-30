import SwiftUI

/// Bottom-sheet style picker. From-scratch implementation.
struct StylePickerView: View {
    @Binding var selectedStyle: CameraStyle
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List {
                ForEach(CameraStyle.allCases, id: \.self) { style in
                    Button {
                        selectedStyle = style
                        dismiss()
                    } label: {
                        HStack(spacing: 14) {
                            Circle()
                                .fill(style.accentColor)
                                .frame(width: 22, height: 22)
                            if selectedStyle == style {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                            }
                            Text(style.title)
                                .foregroundStyle(.primary)
                            Spacer()
                            if selectedStyle == style {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Photo Style")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct StylePickerView_Previews: PreviewProvider {
    static var previews: some View {
        StylePickerView(selectedStyle: .constant(.natural))
    }
}
