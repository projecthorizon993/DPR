import SwiftUI
import AVFoundation

/// Pro mode manual camera controls: ISO, shutter speed, focus, white balance.
///
/// All values are applied to the active AVCaptureDevice via
/// `CameraViewModel`. From-scratch implementation.
struct ProControlsView: View {
    @EnvironmentObject var viewModel: CameraViewModel

    @State private var isoValue: Float = 0
    @State private var shutterValue: Float = 0
    @State private var focusValue: Float = 0
    @State private var wbValue: Float = 0

    var body: some View {
        NavigationView {
            Form {
                Section("ISO") {
                    HStack {
                        Text("ISO")
                        Spacer()
                        Text("\(Int(viewModel.iso))")
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: Binding(
                        get: { viewModel.iso },
                        set: { viewModel.setISO($0) }
                    ), in: viewModel.isoRange.lowerBound...viewModel.isoRange.upperBound)
                }

                Section("Shutter Speed") {
                    HStack {
                        Text("Shutter")
                        Spacer()
                        Text(viewModel.shutterSpeedString)
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: Binding(
                        get: { viewModel.shutterSpeedNormalized },
                        set: { viewModel.setShutterSpeed($0) }
                    ), in: 0...1)
                }

                Section("Focus") {
                    HStack {
                        Text("Focus")
                        Spacer()
                        Text(viewModel.focusPointString)
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: Binding(
                        get: { viewModel.focusValue },
                        set: { viewModel.setFocus($0) }
                    ), in: 0...1)
                }

                Section("White Balance") {
                    HStack {
                        Text("Temp")
                        Spacer()
                        Text("\(Int(viewModel.whiteBalanceTemperature)) K")
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: Binding(
                        get: { viewModel.whiteBalanceNormalized },
                        set: { viewModel.setWhiteBalance($0) }
                    ), in: 0...1)
                }

                Section("Controls") {
                    Button {
                        viewModel.lockExposure()
                    } label: {
                        HStack {
                            Image(systemName: "lock.fill")
                            Text("Lock Exposure")
                        }
                    }
                    Button {
                        viewModel.lockFocus()
                    } label: {
                        HStack {
                            Image(systemName: "lock.fill")
                            Text("Lock Focus")
                        }
                    }
                    Button {
                        viewModel.unlockAll()
                    } label: {
                        HStack {
                            Image(systemName: "lock.open.fill")
                            Text("Unlock All")
                        }
                            .foregroundStyle(.red)
                    }
                }

                Section("RAW Capture") {
                    Toggle("Save DNG/RAW", isOn: $viewModel.rawCaptureEnabled)
                        .disabled(!viewModel.supportsRawCapture || !viewModel.isProMode)
                    if !viewModel.supportsRawCapture {
                        Text("RAW not supported on this device.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if !viewModel.isProMode {
                        Text("Enable Pro mode to use RAW capture.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if viewModel.rawCaptureEnabled {
                        Text("RAW photos save as DNG. Zoom resets to 1.0x during capture.")
                            .font(.caption)
                            .foregroundStyle(.green)
                    }
                }
            }
            .navigationTitle("Pro Controls")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct ProControlsView_Previews: PreviewProvider {
    static var previews: some View {
        ProControlsView()
            .environmentObject(CameraViewModel())
    }
}
