//
//  SettingsView.swift
//  CameraApp
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: CameraService

    var body: some View {
        NavigationView {
            Form {
                Section("Camera") {
                    Toggle("Auto-hide Controls", isOn: Binding(
                        get: { viewModel.showSettings },
                        set: { _ in }
                    ))
                }
            }
            .navigationTitle("Settings")
            .preferredColorScheme(.dark)
        }
    }
}
