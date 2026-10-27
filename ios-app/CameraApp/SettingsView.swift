//
//  SettingsView.swift
//  CameraApp
//
//  App settings: format, watermark, default style.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: CameraViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section("Photo Format") {
                    Picker("Format", selection: $viewModel.selectedStyle) {
                        // Note: format picker would go here; currently bound to style for demo
                        ForEach(CameraStyle.allCases, id: \.self) { style in
                            Text(style.displayName).tag(style)
                        }
                    }
                    .pickerStyle(.inline)
                }

                Section("Watermark") {
                    Toggle("Enable Watermark", isOn: Binding(
                        get: { viewModel.watermarkAlpha > 0 },
                        set: { viewModel.watermarkAlpha = $0 ? 0.6 : 0; viewModel.saveSettings() }
                    ))
                    if viewModel.watermarkAlpha > 0 {
                        Slider(value: Binding(
                            get: { viewModel.watermarkAlpha },
                            set: { viewModel.watermarkAlpha = $0; viewModel.saveSettings() }
                        ), in: 0.1...1.0, step: 0.1) {
                            Text("Opacity")
                        }
                    }
                }

                Section("Default Style") {
                    Picker("Style", selection: $viewModel.selectedStyle) {
                        ForEach(CameraStyle.allCases, id: \.self) { style in
                            Text(style.displayName).tag(style)
                        }
                    }
                    .onChange(of: viewModel.selectedStyle) { _ in
                        viewModel.saveSettings()
                    }
                }

                Section("About") {
                    Text("CameraApp — Personal use only")
                    Text("Color profiles inspired by Xiaomi / OPPO / Vivo camera apps.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    Text("Not affiliated with any brand. Unsigned build for iLoader sideloading.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView(viewModel: CameraViewModel())
    }
}
