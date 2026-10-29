//
//  ContentView.swift
//  CameraApp
//
//  Camera UI ported DIRECTLY from Xiaomi MIUI Camera APK.
//  - Pure black background (#000000)
//  - Amber/orange shutter button (#FFFFCE16)
//  - White text and icons
//  - Large centered shutter button (~74px)
//  - Mode pills at top center (PHOTO / VIDEO)
//  - Flash toggle top-left
//  - Settings top-right
//  - Lens pills vertical stack on LEFT side
//  - Gallery thumbnail bottom-left
//  - Profile/styles selector bottom-right
//  - Recording indicator top-right (red dot + timer)
//  - Post-capture review screen with style badge
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
                    logError("Camera error: \(error.localizedDescription)")
                    viewModel.errorMessage = error.localizedDescription
                    viewModel.showError = true
                }
            )
            .ignoresSafeArea()
            .background(Color.black)

            // ── Xiaomi MIUI Camera overlay ──
            VStack {
                // ── Top bar ──
                HStack(spacing: 0) {
                    // Flash toggle (top-left)
                    Button(action: { viewModel.toggleFlash() }) {
                        Image(systemName: viewModel.flashMode.icon)
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }

                    Spacer()

                    // Mode pills: PHOTO / VIDEO (top center)
                    HStack(spacing: 0) {
                        ModePill(
                            title: "PHOTO",
                            isSelected: !viewModel.isVideoMode
                        ) {
                            viewModel.isVideoMode = false
                        }
                        ModePill(
                            title: "VIDEO",
                            isSelected: viewModel.isVideoMode
                        ) {
                            viewModel.isVideoMode = true
                        }
                    }
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.15))
                            .overlay(
                                Capsule().stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )
                    )

                    Spacer()

                    // Settings (top-right)
                    Button(action: { viewModel.showSettings = true }) {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                Spacer()

                // ── Bottom bar ──
                HStack(spacing: 0) {
                    // Gallery shortcut (bottom-left)
                    Button(action: { viewModel.showGallery = true }) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.15))
                                .frame(width: 64, height: 64)
                            if let thumb = viewModel.lastThumbnail {
                                Image(uiImage: thumb)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 52, height: 52)
                                    .clipShape(Circle())
                            } else {
                                Image(systemName: "photo.on.rectangle")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .frame(width: 64, height: 64)

                    Spacer()

                    // ── Shutter button (center) ──
                    ZStack {
                        // Photo: amber (#FFFFCE16) / Recording: red
                        if viewModel.isVideoMode && viewModel.isRecording {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 74, height: 74)
                        } else {
                            Circle()
                                .fill(Color(hex: "FFFFCE16"))
                                .frame(width: 74, height: 74)
                        }
                    }
                    .scaleEffect(viewModel.shutterPressed ? 0.92 : 1.0)
                    .animation(.easeInOut(duration: 0.08), value: viewModel.shutterPressed)
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
                    .frame(width: 74, height: 74)

                    Spacer()

                    // Styles / Profiles (bottom-right)
                    Button(action: { viewModel.showStylePicker = true }) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.15))
                                .frame(width: 64, height: 64)
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(viewModel.selectedStyle.accentColor)
                                    .frame(width: 10, height: 10)
                                Text(viewModel.selectedStyle.shortName)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .frame(width: 64, height: 64)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 34)

                // ── Lens pills (vertical stack on LEFT side) ──
                HStack(spacing: 0) {
                    VStack(spacing: 10) {
                        LensPill(
                            title: "0.5×",
                            isSelected: viewModel.selectedLens == .ultraWide
                        ) {
                            viewModel.selectedLens = .ultraWide
                            viewModel.switchToUltraWide()
                        }
                        LensPill(
                            title: "1×",
                            isSelected: viewModel.selectedLens == .wide
                        ) {
                            viewModel.selectedLens = .wide
                            viewModel.switchToWide()
                        }
                        LensPill(
                            title: "2×",
                            isSelected: viewModel.selectedLens == .telephoto
                        ) {
                            viewModel.selectedLens = .telephoto
                            viewModel.switchToTelephoto()
                        }
                    }
                    .padding(.top, 60)   // below top bar
                    .padding(.bottom, 100) // above bottom bar

                    Spacer()
                }
                .padding(.leading, 16)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // ── Recording indicator (top right) ──
            if viewModel.isVideoMode && viewModel.isRecording {
                VStack {
                    HStack {
                        Spacer()
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 8, height: 8)
                                .scaleEffect(1.0)
                                .animation(
                                    .easeInOut(duration: 1.0)
                                    .repeatForever(autoreverses: true),
                                    value: viewModel.isRecording
                                )
                            Text(viewModel.recordTime)
                                .font(.system(size: 14, weight: .medium, design: .monospaced))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(Color.black.opacity(0.6)))
                    }
                    .padding(.top, 10)
                    .padding(.trailing, 20)
                    Spacer()
                }
                .ignoresSafeArea()
            }

            // ── Loading overlay ──
            if viewModel.isProcessing {
                ZStack {
                    Color.black.opacity(0.6).ignoresSafeArea()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.4)
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

// MARK: - Mode pill (Xiaomi MIUI style)

struct ModePill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(isSelected ? Color(hex: "FFFFCE16") : .white)
                .frame(width: 52, height: 26)
        }
        .buttonStyle(PlainButtonStyle())
        .background(
            RoundedRectangle(cornerRadius: 13)
                .fill(isSelected ? Color(hex: "FFFFCE16").opacity(0.18) : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 13)
                        .stroke(isSelected ? Color(hex: "FFFFCE16") : Color.white.opacity(0.35), lineWidth: 1)
                )
        )
    }
}

// MARK: - Lens pill (vertical left side)

struct LensPill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundColor(isSelected ? Color(hex: "FFFFCE16") : .white)
                .frame(width: 40, height: 24)
        }
        .buttonStyle(PlainButtonStyle())
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? Color(hex: "FFFFCE16").opacity(0.18) : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Color(hex: "FFFFCE16") : Color.white.opacity(0.35), lineWidth: 1)
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
