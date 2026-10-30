import SwiftUI

/// Main camera interface: live preview, shutter/record, style picker, settings,
/// lens selector, flash toggle, and post-capture review overlay. From-scratch implementation.
struct ContentView: View {
    @EnvironmentObject var viewModel: CameraViewModel

    @State private var showingSettings = false
    @State private var showingStylePicker = false
    @State private var mode: CaptureMode = .photo

    var body: some View {
        ZStack {
            // Live preview (raw camera feed).
            CameraView()
                .ignoresSafeArea()

            // Live processed frame overlay (styled preview).
            if let processed = viewModel.processedFrame {
                Image(uiImage: processed)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
                    .opacity(0.85)
            }

            // Dim when reviewing.
            if viewModel.isReviewing {
                Color.black.opacity(0.55)
                    .ignoresSafeArea()
                    .transition(.opacity)
            }

            // Recording indicator.
            if viewModel.isRecording {
                VStack {
                    HStack {
                        Spacer()
                        recordingIndicator
                            .padding(.trailing, 24)
                            .padding(.top, 44)
                    }
                    Spacer()
                }
            }

            // Top bar.
            VStack {
                HStack {
                    Button { showingSettings = true } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 26, weight: .regular))
                            .foregroundStyle(.white)
                            .padding()
                    }
                    .accessibilityLabel("Settings")

                    Spacer()

                    // Mode pills (PHOTO / VIDEO).
                    HStack(spacing: 8) {
                        modePill("PHOTO", isSelected: mode == .photo)
                        modePill("VIDEO", isSelected: mode == .video)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.35))
                    .clipShape(Capsule())
                    .padding(.trailing)
                }
                .padding(.top, 44)

                Spacer()
            }

            // Controls overlay.
            VStack {
                Spacer()

                // Style selector (bottom right).
                HStack {
                    Spacer()
                    styleSelectorButton
                        .padding(.trailing, 24)
                        .padding(.bottom, 22)
                }

                // Flash toggle (above style selector).
                HStack {
                    Spacer()
                    flashToggleButton
                        .padding(.trailing, 24)
                        .padding(.bottom, 78)
                }

                // Shutter / record (center bottom).
                HStack {
                    Spacer()

                    if mode == .video {
                        videoRecordButton
                    } else {
                        shutterButton
                    }

                    Spacer()
                }
                .padding(.bottom, 24)

                // Lens selector (bottom left).
                HStack {
                    lensSelectorButton
                        .padding(.leading, 24)
                        .padding(.bottom, 24)

                    Spacer()
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showingStylePicker) {
            StylePickerView(selectedStyle: $viewModel.selectedStyle)
        }
        .overlay(reviewOverlay, alignment: .center)
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK", role: .cancel) {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    // MARK: - Subviews

    private var shutterButton: some View {
        Button {
            viewModel.capturePhoto()
        } label: {
            Circle()
                .fill(Color.white)
                .frame(width: 74, height: 74)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.35), lineWidth: 4)
                        .frame(width: 82, height: 82)
                )
                .scaleEffect(viewModel.isCaptureInProgress ? 0.92 : 1.0)
                .animation(.spring(response: 0.2, dampingFraction: 0.6), value: viewModel.isCaptureInProgress)
        }
        .disabled(viewModel.isCaptureInProgress)
        .accessibilityLabel("Shutter")
    }

    private var videoRecordButton: some View {
        Button {
            viewModel.toggleVideoRecording()
        } label: {
            Circle()
                .fill(viewModel.isRecording ? Color.red : Color.white)
                .frame(width: 74, height: 74)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.35), lineWidth: 4)
                        .frame(width: 82, height: 82)
                )
                .scaleEffect(viewModel.isRecording ? 0.92 : 1.0)
                .animation(.spring(response: 0.2, dampingFraction: 0.6), value: viewModel.isRecording)
        }
        .disabled(viewModel.isCaptureInProgress)
        .accessibilityLabel(viewModel.isRecording ? "Stop recording" : "Start recording")
    }

    private var galleryButton: some View {
        Button {
            // Placeholder: open last thumbnail.
        } label: {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.black.opacity(0.35))
                .frame(width: 56, height: 56)
                .overlay(
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 20))
                        .foregroundStyle(.white)
                )
        }
        .accessibilityLabel("Gallery")
    }

    private var styleSelectorButton: some View {
        Button { showingStylePicker = true } label: {
            ZStack {
                Circle()
                    .fill(Color.black.opacity(0.45))
                    .frame(width: 46, height: 46)
                Circle()
                    .fill(viewModel.selectedStyle.accentColor)
                    .frame(width: 26, height: 26)
                Text(viewModel.selectedStyle.initials)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .accessibilityLabel("Select photo style: \(viewModel.selectedStyle.title)")
    }

    private var flashToggleButton: some View {
        Button {
            viewModel.toggleFlash()
        } label: {
            ZStack {
                Circle()
                    .fill(Color.black.opacity(0.45))
                    .frame(width: 46, height: 46)
                Image(systemName: flashIconName)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(viewModel.flashMode == .off ? Color.white.opacity(0.5) : Color.white)
                if viewModel.flashMode == .on {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 8, height: 8)
                        .offset(x: 10, y: -10)
                }
            }
        }
        .accessibilityLabel("Flash \(viewModel.flashMode.title)")
    }

    private var lensSelectorButton: some View {
        Menu {
            ForEach(CameraLens.allCases, id: \.self) { lens in
                Button {
                    viewModel.switchLens(lens)
                } label: {
                    HStack {
                        Text(lens.title)
                        if viewModel.lens == lens {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            ZStack {
                Circle()
                    .fill(Color.black.opacity(0.45))
                    .frame(width: 46, height: 46)
                Text(viewModel.lens.title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .accessibilityLabel("Select lens: \(viewModel.lens.title)")
    }

    private var recordingIndicator: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color.red)
                .frame(width: 10, height: 10)
                .scaleEffect(viewModel.isRecording ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: viewModel.isRecording)
            Text("REC")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.6))
        .clipShape(Capsule())
    }

    private var flashIconName: String {
        switch viewModel.flashMode {
        case .off: return "bolt.slash.fill"
        case .on: return "bolt.fill"
        case .auto: return "bolt.circle.fill"
        }
    }

    private func modePill(_ title: String, isSelected: Bool) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(isSelected ? Color.black : Color.white)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .onTapGesture {
                mode = isSelected ? .photo : .video
            }
    }

    @ViewBuilder
    private var reviewOverlay: some View {
        if viewModel.isReviewing, let image = viewModel.capturedImage {
            ReviewView(image: image, onDismiss: {
                viewModel.dismissReview()
            }, onSave: {
                viewModel.savePhoto(image)
                viewModel.dismissReview()
            })
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

enum CaptureMode {
    case photo, video
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(CameraViewModel())
    }
}
