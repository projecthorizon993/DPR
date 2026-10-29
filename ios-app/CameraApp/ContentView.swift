//
//  ContentView.swift
//  CameraApp
//
//  Ported DIRECTLY from Xiaomi MIUI Camera APK (decompiled layout values).
//  Exact values from xiaomi-deobf:
//  - Shutter: 93dp (bq7), amber #ffffce16 fill, dark outer ring
//  - Gallery: 66dp (bqi)
//  - Lens/Style containers: 54dp (bpi)
//  - Top bar height: 60dp (eap)
//  - Animation: 150ms decelerate (ev_), 220ms (ev9)
//  - Amber: #ffffce16, Dark text on amber: #111111
//

import SwiftUI
import PhotosUI
import UIKit

struct ContentView: View {
    @StateObject private var viewModel = CameraViewModel()

    var body: some View {
        ZStack {
            // ── Camera preview (full bleed, black) ──
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
                    withAnimation(.easeInOut(duration: 0.15)) {
                        viewModel.isRecording = true
                    }
                    viewModel.startRecordingTimer()
                },
                onRecordingStopped: {
                    withAnimation(.easeInOut(duration: 0.15)) {
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
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(viewModel.flashMode == .on ? Color(hex: "ffffce16") : .white)
                            .frame(width: 56, height: 56)
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
                            .fill(Color.white.opacity(0.10))
                            .overlay(
                                Capsule().stroke(Color.white.opacity(0.24), lineWidth: 1)
                            )
                    )
                    .frame(height: 30)

                    Spacer()

                    // Settings (top-right) — ellipsis like Xiaomi
                    Button(action: { viewModel.showSettings = true }) {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 56, height: 56)
                            .contentShape(Rectangle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)

                Spacer()

                // ── Bottom bar: Gallery | Shutter | Style ──
                HStack(spacing: 0) {
                    // Gallery shortcut (bottom-left, 66dp)
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
                                    .font(.system(size: 20, weight: .medium))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .frame(width: 66, height: 66)

                    Spacer()

                    // ── Shutter button (center, amber #ffffce16, 93dp) ──
                    ZStack {
                        // Outer dark ring
                        Circle()
                            .stroke(Color.white.opacity(0.25), lineWidth: 3)
                            .frame(width: 93, height: 93)
                        // Inner amber circle
                        if viewModel.isVideoMode && viewModel.isRecording {
                            Circle()
                                .fill(Color(hex: "ffe11b1b"))
                                .frame(width: 80, height: 80)
                        } else {
                            Circle()
                                .fill(Color(hex: "ffffce16"))
                                .frame(width: 80, height: 80)
                        }
                    }
                    .scaleEffect(viewModel.shutterPressed ? 0.88 : 1.0)
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
                    .frame(width: 93, height: 93)

                    Spacer()

                    // Styles / Profiles (bottom-right, 70dp container)
                    Button(action: { viewModel.showStylePicker = true }) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.15))
                                .frame(width: 70, height: 70)
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(viewModel.selectedStyle.accentColor)
                                    .frame(width: 11, height: 11)
                                Text(viewModel.selectedStyle.shortName)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .frame(width: 70, height: 70)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // ── Lens pills: vertical stack on LEFT ──
            VStack(spacing: 12) {
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
            .padding(.leading, 22)
            .padding(.top, 70)     // below top bar (60dp + margin)
            .padding(.bottom, 130) // above bottom bar

            // ── Recording indicator (top-right) ──
            if viewModel.isVideoMode && viewModel.isRecording {
                VStack {
                    HStack {
                        Spacer()
                        HStack(spacing: 7) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 8, height: 8)
                                .animation(
                                    .easeInOut(duration: 0.8)
                                    .repeatForever(autoreverses: true),
                                    value: viewModel.isRecording
                                )
                            Text(viewModel.recordTime)
                                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.black.opacity(0.65)))
                    }
                    .padding(.top, 14)
                    .padding(.trailing, 24)
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

// MARK: - Mode pill (Xiaomi: selected = amber fill + dark text #111111)

struct ModePill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(isSelected ? Color(red: 0.067, green: 0.067, blue: 0.067) : .white)
                .frame(width: 56, height: 28)
        }
        .buttonStyle(PlainButtonStyle())
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color(hex: "ffffce16") : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isSelected ? Color.clear : Color.white.opacity(0.24), lineWidth: 1)
                )
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

// MARK: - Lens pill (vertical left, Xiaomi style)

struct LensPill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundColor(isSelected ? Color(red: 0.067, green: 0.067, blue: 0.067) : .white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .frame(width: 44, height: 28)
        }
        .buttonStyle(PlainButtonStyle())
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color(hex: "ffffce16") : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isSelected ? Color.clear : Color.white.opacity(0.24), lineWidth: 1)
                )
        )
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

// MARK: - Color extension (Xiaomi amber #ffffce16)

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
