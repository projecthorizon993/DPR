//
//  ContentView.swift
//  CameraApp
//
//  Main camera UI — reimplemented from vivo/Xiaomi camera APK layouts.
//  - Shutter: large centered circle with press scale animation (vivo anim_shutter_button_pressed)
//  - Zoom: vertical pills on left (vivo zoom_button.xml)
//  - Top bar: transparent, flash left, mode pills center, settings right (vivo top_bar_1_5_layout)
//  - Recording: red dot + timer overlay (vivo video_module.xml)
//  - Watermark: bottom-right Zeiss logo + text (vivo watermark_small_banner_text.xml)
//  - Colors: black bg, white text, orange selected (Xiaomi colors.xml)
//

import SwiftUI
import PhotosUI
import UIKit

struct ContentView: View {
    @StateObject private var viewModel = CameraViewModel()

    var body: some View {
        ZStack {
            // ── Camera preview (full bleed) ──
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

            // ── Top bar (vivo top_bar_1_5_layout pattern) ──
            VStack {
                HStack(spacing: 24) {
                    // Flash (left)
                    Button(action: { viewModel.toggleFlash() }) {
                        Image(systemName: viewModel.flashMode.icon)
                            .font(.system(size: 22, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 48, height: 48)
                    }

                    Spacer()

                    // Mode pills: PHOTO / VIDEO (center)
                    HStack(spacing: 6) {
                        ModePill(title: "PHOTO", isSelected: !viewModel.isVideoMode) {
                            viewModel.isVideoMode = false
                        }
                        ModePill(title: "VIDEO", isSelected: viewModel.isVideoMode) {
                            viewModel.isVideoMode = true
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.black.opacity(0.45)))

                    Spacer()

                    // Settings (right)
                    Button(action: { viewModel.showSettings = true }) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 48, height: 48)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .background(
                    LinearGradient(
                        colors: [Color.black.opacity(0.35), Color.black.opacity(0)],
                        startPoint: .top, endPoint: .bottom
                    )
                )

                Spacer()

                // ── Bottom controls ──
                HStack {
                    // Gallery shortcut (left)
                    Button(action: { viewModel.showGallery = true }) {
                        ZStack {
                            Circle()
                                .fill(Color.black.opacity(0.5))
                                .frame(width: 64, height: 64)
                            if let thumb = viewModel.lastThumbnail {
                                Image(uiImage: thumb)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 52, height: 52)
                                    .clipShape(Circle())
                            } else {
                                Image(systemName: "photo.on.rectangle")
                                    .font(.system(size: 22))
                                    .foregroundColor(.white)
                            }
                        }
                    }

                    Spacer()

                    // ── Shutter button (center, vivo pattern) ──
                    Button(action: {
                        if viewModel.isVideoMode {
                            viewModel.toggleVideo()
                        } else {
                            viewModel.capturePhoto()
                        }
                    }) {
                        ZStack {
                            if viewModel.isVideoMode && viewModel.isRecording {
                                Circle()
                                    .stroke(Color.red, lineWidth: 4)
                                    .frame(width: 88, height: 88)
                                    .scaleEffect(viewModel.shutterPressed ? 0.9 : 1.0)
                                    .animation(.easeInOut(duration: 0.1), value: viewModel.shutterPressed)
                                Circle().fill(Color.red)
                                    .frame(width: 68, height: 68)
                                    .scaleEffect(viewModel.shutterPressed ? 0.9 : 1.0)
                                    .animation(.easeInOut(duration: 0.1), value: viewModel.shutterPressed)
                            } else {
                                Circle()
                                    .stroke(Color.white, lineWidth: 5)
                                    .frame(width: 88, height: 88)
                                    .scaleEffect(viewModel.shutterPressed ? 0.9 : 1.0)
                                    .animation(.easeInOut(duration: 0.1), value: viewModel.shutterPressed)
                                Circle()
                                    .fill(viewModel.isVideoMode ? Color.red : Color.white)
                                    .frame(width: 68, height: 68)
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
                        HStack(spacing: 6) {
                            Circle()
                                .fill(viewModel.selectedStyle.accentColor)
                                .frame(width: 10, height: 10)
                            Text(viewModel.selectedStyle.displayName)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color.black.opacity(0.5)))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 34)

                // ── Zoom pills (left side vertical — vivo zoom_button.xml pattern) ──
                VStack(spacing: 12) {
                    ZoomPill(title: "0.5×", isSelected: viewModel.selectedLens == .ultraWide) {
                        viewModel.selectedLens = .ultraWide
                        viewModel.switchToUltraWide()
                    }
                    ZoomPill(title: "1×", isSelected: viewModel.selectedLens == .wide) {
                        viewModel.selectedLens = .wide
                        viewModel.switchToWide()
                    }
                    ZoomPill(title: "2×", isSelected: viewModel.selectedLens == .telephoto) {
                        viewModel.selectedLens = .telephoto
                        viewModel.switchToTelephoto()
                    }
                }
                .padding(.leading, 20)
                .padding(.bottom, 90)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            // ── Recording indicator overlay (top, vivo video_module.xml pattern) ──
            if viewModel.isVideoMode && viewModel.isRecording {
                VStack {
                    HStack {
                        Spacer()
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 8, height: 8)
                            Text(viewModel.recordTime)
                                .font(.system(size: 17, weight: .medium, design: .monospaced))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.black.opacity(0.6)))
                    }
                    .padding(.top, 46)
                    .padding(.trailing, 20)
                    Spacer()
                }
            }

            // ── Loading overlay ──
            if viewModel.isProcessing {
                ZStack {
                    Color.black.opacity(0.6).ignoresSafeArea()
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
        }
    }
}

// MARK: - Mode pill (top bar)

struct ModePill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(isSelected ? .white : .white.opacity(0.7))
                .frame(width: 56, height: 28)
        }
        .buttonStyle(PlainButtonStyle())
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(isSelected ? Color.white.opacity(0.2) : Color.clear)
        )
    }
}

// MARK: - Zoom pill (left side vertical)

struct ZoomPill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 15, weight: .medium, design: .monospaced))
                .foregroundColor(isSelected ? Color.orange : .white)
                .frame(width: 48, height: 30)
        }
        .buttonStyle(PlainButtonStyle())
        .background(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.orange : Color.white.opacity(0.5), lineWidth: 1.5)
        )
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
