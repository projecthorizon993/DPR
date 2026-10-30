import SwiftUI

/// Main camera interface: live preview, shutter, style picker, settings, gallery,
/// and post-capture review overlay. From-scratch implementation.
struct ContentView: View {
    @EnvironmentObject var viewModel: CameraViewModel

    @State private var showingSettings = false
    @State private var showingStylePicker = false

    var body: some View {
        ZStack {
            // Live preview.
            CameraView()
                .ignoresSafeArea()

            // Dim when reviewing.
            if viewModel.isReviewing {
                Color.black.opacity(0.55)
                    .ignoresSafeArea()
                    .transition(.opacity)
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
                        modePill("PHOTO", isSelected: true)
                        modePill("VIDEO", isSelected: false)
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

                // Shutter + gallery (bottom center / left).
                HStack {
                    // Gallery shortcut (bottom left).
                    galleryButton
                        .padding(.leading, 24)
                        .padding(.bottom, 24)

                    Spacer()

                    // Shutter button (center bottom).
                    shutterButton
                        .padding(.bottom, 24)
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

    private func modePill(_ title: String, isSelected: Bool) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(isSelected ? Color.black : Color.white)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
    }

    @ViewBuilder
    private var reviewOverlay: some View {
        if viewModel.isReviewing, let image = viewModel.capturedImage {
            ReviewView(image: image, onDismiss: {
                viewModel.dismissReview()
            }, onSave: {
                PhotoLibrary.save(image)
                viewModel.dismissReview()
            })
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(CameraViewModel())
    }
}
