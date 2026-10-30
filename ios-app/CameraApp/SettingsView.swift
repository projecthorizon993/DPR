import SwiftUI

/// App settings: watermark toggle, format, style. From-scratch implementation.
struct SettingsView: View {
    @AppStorage("watermarkEnabled") private var watermarkEnabled = true
    @AppStorage("videoWatermarkEnabled") private var videoWatermarkEnabled = true
    @AppStorage("photoFormat") private var photoFormat = "HEIF"
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section("Capture") {
                    Toggle("Watermark on saved photos", isOn: $watermarkEnabled)
                    Toggle("Watermark on recorded videos", isOn: $videoWatermarkEnabled)
                    Picker("Photo format", selection: $photoFormat) {
                        Text("HEIF").tag("HEIF")
                        Text("JPEG").tag("JPEG")
                    }
                    .pickerStyle(.segmented)
                }

                Section("About") {
                    HStack {
                        Text("App")
                        Spacer()
                        Text("CameraApp 1.0")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Build")
                        Spacer()
                        Text("from scratch — no reused code")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
