//
//  ContentView.swift
//  CameraApp
//
//  Camera UI ported faithfully from Xiaomi MIUI Camera APK.
//  - Black background (#000000)
//  - Amber/orange shutter button (#FFFFCE16)
//  - White text
//  - Large centered shutter button
//  - Mode pills at top center
//  - Flash toggle top-left
//  - Lens pills vertical on left side
//  - Gallery thumbnail bottom-left
//  - Settings top-right
//  - Profile/styles selector bottom-right
//

import SwiftUI
import PhotosUI
import UIKit

struct ContentView: View {
    @StateObject private var viewModel = CameraViewModel()

    var body: some View {
        ZStack {
            // ── Camera preview (full bleed, black background) ──
            CameraViewRepresentable(
                viewModel: viewModel,
                onPhotoCaptured: { image in
                    viewModel.reviewImage = image
                    viewModel.showReview = true
                },
                onVideoRecorded: { url in
                    viewModel.reviewVideoURL = url
                    viewModel.showReview = true
                },
                onRecordingStarted: {
                    viewModel.isRecording = true
                    viewModel.startRecordingTimer()
                },
                onRecordingStopped: {
                    viewModel.isRecording = false
                    viewModel.stopRecordingTimer()
                },
                onError: { error in
                    viewModel.errorMessage = error.localizedDescription
                    viewModel.showError = true
                }
            )
            .ignoresSafeArea()
            .background(Color.black)

            // ── Xiaomi UI Overlay ──
            VStack {
                // Top bar: Flash | Mode pills | Settings
                HStack(spacing: 20) {
                    // Flash (left)
                    Button(action: { viewModel.toggleFlash() }) {
                        Image(systemName: viewModel.flashMode.icon)
                            .font(.system(size: 22, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 48, height: 48)
                    }

                    Spacer()

                    // Mode pills: PHOTO | VIDEO (center)
                    HStack(spacing: 8) {
                        ModePill(title: "PHOTO", isSelected: !viewModel.isVideoMode) {
                            viewModel.isVideoMode = false
                        }
                        ModePill(title: "VIDEO", isSelected: viewModel.isVideoMode) {
                            viewModel.isVideoMode = true
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.white.opacity(0.15))
                            .overlay(
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )
                    )

                    Spacer()

                    // Settings (right)
                    Button(action: { viewModel.showSettings = true }) {
                        Image(systemName: "line.horizontal.3.decrease.circle")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 48, height: 48)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)

                Spacer()

                // Bottom controls: Gallery | Shutter | Styles
                HStack {
                    // Gallery shortcut (left)
                    Button(action: { viewModel.showGallery = true }) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.15))
                                .frame(width: 60, height: 60)
                            if let thumb = viewModel.lastThumbnail {
                                Image(uiImage: thumb)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 48, height: 48)
                                    .clipShape(Circle())
                            } else {
                                Image(systemName: "photo.on.rectangle")
                                    .font(.system(size: 20))
                                    .foregroundColor(.white)
                            }
                        }
                    }

                    Spacer()

                    // ── Shutter button (center, Xiaomi style - large amber circle) ──
                    Button(action: {
                        if viewModel.isVideoMode {
                            viewModel.toggleVideo()
                        } else {
                            viewModel.capturePhoto()
                        }
                    }) {
                        ZStack {
                            if viewModel.isVideoMode && viewModel.isRecording {
                                // Recording: red shutter
                                Circle()
                                    .stroke(Color.red, lineWidth: 4)
                                    .frame(width: 90, height: 90)
                                    .scaleEffect(viewModel.shutterPressed ? 0.9 : 1.0)
                                    .animation(.easeInOut(duration: 0.1), value: viewModel.shutterPressed)
                                Circle().fill(Color.red)
                                    .frame(width: 70, height: 70)
                                    .scaleEffect(viewModel.shutterPressed ? 0.9 : 1.0)
                                    .animation(.easeInOut(duration: 0.1), value: viewModel.shutterPressed)
                            } else {
                                // Photo: amber/orange shutter (Xiaomi style #FFFFCE16)
                                Circle()
                                    .fill(Color.white.opacity(0.2))
                                    .frame(width: 90, height: 90)
                                    .scaleEffect(viewModel.shutterPressed ? 0.9 : 1.0)
                                    .animation(.easeInOut(duration: 0.1), value: viewModel.shutterPressed)
                                Circle()
                                    .fill(Color(hex: "FFFFCE16"))
                                    .frame(width: 70, height: 70)
                                    .scaleEffect(viewModel.shutterPressed ? 0.9 : 1.0)
                                    .animation(.easeInOut(duration: 0.1), value: viewModel.shutterPressed)
                            }
                        }
                    }
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { _ in viewModel.shutterPressed = true }
                            .onEnded { _ in
                                viewModel.shutterPressed = false
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                    viewModel.shutterPressed = false
                                }
                            }
                    )
                    .disabled(viewModel.isProcessing)

                    Spacer()

                    // Styles / Profiles (right)
                    Button(action: { viewModel.showStylePicker = true }) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.15))
                                .frame(width: 60, height: 60)
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(viewModel.selectedStyle.accentColor)
                                    .frame(width: 8, height: 8)
                                Text(viewModel.selectedStyle.shortName)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 34)

                // ── Lens pills (vertical on left side) ──
                HStack(spacing: 12) {
                    VStack(spacing: 10) {
                        LensPill(title: "0.5×", isSelected: viewModel.selectedLens == .ultraWide) {
                            viewModel.selectedLens = .ultraWide
                            viewModel.switchToUltraWide()
                        }
                        LensPill(title: "1×", isSelected: viewModel.selectedLens == .wide) {
                            viewModel.selectedLens = .wide
                            viewModel.switchToWide()
                        }
                        LensPill(title: "2×", isSelected: viewModel.selectedLens == .telephoto) {
                            viewModel.selectedLens = .telephoto
                            viewModel.switchToTelephoto()
                        }
                    }
                    Spacer()
                }
                .padding(.leading, 16)
                .padding(.bottom, 100)
            }

            // ── Recording indicator (top, Xiaomi style) ──
            if viewModel.isVideoMode && viewModel.isRecording {
                VStack {
                    HStack {
                        Spacer()
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 8, height: 8)
                            Text(viewModel.recordTime)
                                .font(.system(size: 15, weight: .medium, design: .monospaced))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Color.black.opacity(0.7)))
                    }
                    .padding(.top, 46)
                    .padding(.trailing, 20)
                    Spacer()
                }
            }

            // ── Loading overlay ──
            if viewModel.isProcessing {
                ZStack {
                    Color.black.opacity(0.7).ignoresSafeArea()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                }
            }
        }
        .sheet(isPresented: $viewModel.showStylePicker) {
            StylePickerView(selectedStyle: $viewModel.selectedStyle)
        }
        .sheet(isPresented: $viewModel.showSettings) {
            SettingsView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showGallery) {
            GalleryView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showReview) {
            ReviewView(
                image: $viewModel.reviewImage,
                videoURL: $viewModel.reviewVideoURL,
                isPresented: $viewModel.showReview,
                onSave: { viewModel.showReview = false },
                onRetake: { viewModel.showReview = false }
            )
        }
        .alert("Camera Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "Unknown error")
        }
        .onAppear {
            viewModel.requestPermissions()
            viewModel.loadLastThumbnailAsync()
        }
    }
}

// MARK: - Mode pill (Xiaomi style - pill with stroke)

struct ModePill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(isSelected ? Color(hex: "FFFFCE16") : .white)
                .frame(width: 56, height: 28)
        }
        .buttonStyle(PlainButtonStyle())
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(isSelected ? Color(hex: "FFFFCE16").opacity(0.2) : Color.white.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(isSelected ? Color(hex: "FFFFCE16") : Color.white.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Lens pill (vertical left side, Xiaomi style)

struct LensPill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundColor(isSelected ? Color(hex: "FFFFCE16") : .white)
                .frame(width: 44, height: 28)
        }
        .buttonStyle(PlainButtonStyle())
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(isSelected ? Color(hex: "FFFFCE16").opacity(0.2) : Color.white.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(isSelected ? Color(hex: "FFFFCE16") : Color.white.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

// MARK: - Color extension (Xiaomi colors)

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255.0
        let g = Double((int >> 8) & 0xFF) / 255.0
        let b = Double(int & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
