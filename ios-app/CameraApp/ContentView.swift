//
//  ContentView.swift
//  CameraApp
//
//  Ported DIRECTLY from Xiaomi MIUI Camera APK (reference screenshots applied).
//  Layout matches Xiaomi exactly:
//  - Pure black background
//  - Amber shutter (#FFFFCE16), large centered
//  - PHOTO/VIDEO mode pills top center (selected = amber fill + dark text)
//  - Flash top-left, Settings (ellipsis) top-right
//  - Lens pills vertical LEFT (0.5× / 1× / 2×, selected = amber fill)
//  - Gallery bottom-left, Style bottom-right (same row as shutter)
//  - Recording indicator top-right (red dot + timer)
//  - Animations: shutter press, pill switch, lens switch, appear
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
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.isRecording = true
                    }
                    viewModel.startRecordingTimer()
                },
                onRecordingStopped: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.isRecording = false
                    }
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

            // ── Top bar: Flash | Mode pills | Settings ──
            VStack {
                HStack(spacing: 0) {
                    // Flash toggle (top-left)
                    Button(action: { viewModel.toggleFlash() }) {
                        Image(systemName: viewModel.flashMode.icon)
                            .font(.system(size: 22, weight: .medium))
                            .foregroundColor(viewModel.flashMode == .on ? Color(hex: "FFFFCE16") : .white)
                            .frame(width: 48, height: 48)
                            .contentShape(Rectangle())
                    }

                    Spacer()

                    // Mode pills: PHOTO / VIDEO (top center)
                    HStack(spacing: 0) {
                        ModePill(
                            title: "PHOTO",
                            isSelected: !viewModel.isVideoMode
                        ) {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                viewModel.isVideoMode = false
                            }
                        }
                        ModePill(
                            title: "VIDEO",
                            isSelected: viewModel.isVideoMode
                        ) {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                viewModel.isVideoMode = true
                            }
                        }
                    }
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.12))
                            .overlay(
                                Capsule().stroke(Color.white.opacity(0.3), lineWidth: 1)
                            )
                    )

                    Spacer()

                    // Settings (top-right)
                    Button(action: { viewModel.showSettings = true }) {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 48, height: 48)
                            .contentShape(Rectangle())
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 10)

                Spacer()

                // ── Bottom bar: Gallery | Shutter | Styles ──
                HStack(spacing: 0) {
                    // Gallery shortcut (bottom-left)
                    Button(action: { viewModel.showGallery = true }) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.15))
                                .frame(width: 66, height: 66)
                            if let thumb = viewModel.lastThumbnail {
                                Image(uiImage: thumb)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 54, height: 54)
                                    .clipShape(Circle())
                            } else {
                                Image(systemName: "photo.on.rectangle")
                                    .font(.system(size: 19, weight: .medium))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .frame(width: 66, height: 66)

                    Spacer()

                    // ── Shutter button (center) ──
                    ZStack {
                        if viewModel.isVideoMode && viewModel.isRecording {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 78, height: 78)
                        } else {
                            Circle()
                                .fill(Color(hex: "FFFFCE16"))
                                .frame(width: 78, height: 78)
                        }
                    }
                    .scaleEffect(viewModel.shutterPressed ? 0.86 : 1.0)
                    .animation(.easeInOut(duration: 0.08), value: viewModel.shutterPressed)
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { _ in
                                if !viewModel.shutterPressed {
                                    viewModel.shutterPressed = true
                                }
                            }
                            .onEnded { _ in
                                viewModel.shutterPressed = false
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                    viewModel.shutterPressed = false
                                }
                            }
                    )
                    .disabled(viewModel.isProcessing)
                    .frame(width: 78, height: 78)

                    Spacer()

                    // Styles / Profiles (bottom-right)
                    Button(action: { viewModel.showStylePicker = true }) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.15))
                                .frame(width: 66, height: 66)
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
                    .frame(width: 66, height: 66)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 38)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // ── Lens pills (vertical stack on LEFT side) ──
            VStack(spacing: 10) {
                LensPill(
                    title: "0.5×",
                    isSelected: viewModel.selectedLens == .ultraWide
                ) {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        viewModel.selectedLens = .ultraWide
                        viewModel.switchToUltraWide()
                    }
                }
                LensPill(
                    title: "1×",
                    isSelected: viewModel.selectedLens == .wide
                ) {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        viewModel.selectedLens = .wide
                        viewModel.switchToWide()
                    }
                }
                LensPill(
                    title: "2×",
                    isSelected: viewModel.selectedLens == .telephoto
                ) {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        viewModel.selectedLens = .telephoto
                        viewModel.switchToTelephoto()
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 20)
            .padding(.top, 70)     // below top bar
            .padding(.bottom, 120) // above bottom bar

            // ── Recording indicator (top right) ──
            if viewModel.isVideoMode && viewModel.isRecording {
                VStack {
                    HStack {
                        Spacer()
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 8, height: 8)
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

// MARK: - Mode pill (Xiaomi MIUI: selected = amber fill + dark text)

struct ModePill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(isSelected ? Color(red: 0.18, green: 0.18, blue: 0.18) : .white)
                .frame(width: 52, height: 26)
        }
        .buttonStyle(PlainButtonStyle())
        .background(
            RoundedRectangle(cornerRadius: 13)
                .fill(isSelected ? Color(hex: "FFFFCE16") : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 13)
                        .stroke(isSelected ? Color.clear : Color.white.opacity(0.35), lineWidth: 1)
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
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundColor(isSelected ? Color(red: 0.18, green: 0.18, blue: 0.18) : .white)
                .frame(width: 40, height: 24)
        }
        .buttonStyle(PlainButtonStyle())
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? Color(hex: "FFFFCE16") : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Color.clear : Color.white.opacity(0.35), lineWidth: 1)
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
