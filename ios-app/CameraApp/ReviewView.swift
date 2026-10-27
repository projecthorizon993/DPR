//
//  ReviewView.swift
//  CameraApp
//
//  Post-capture review: show processed photo/video with style badge.
//

import SwiftUI
import UIKit

struct ReviewView: View {
    @Binding var image: UIImage?
    @Binding var videoURL: URL?
    @Binding var isPresented: Bool
    let onSave: () -> Void
    let onRetake: () -> Void

    @State private var showingShare = false

    var body: some View {
        NavigationView {
            ZStack {
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black)
                } else if let url = videoURL {
                    VideoPreviewView(url: url)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black)
                }
            }
            .overlay(alignment: .topTrailing) {
                HStack(spacing: 12) {
                    if image != nil {
                        Text("STYLE APPLIED")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.orange)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(Color.black.opacity(0.6)))
                    }
                    Button(action: { showingShare = true }) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 22))
                            .foregroundColor(.white)
                    }
                }
                .padding()
            }
            .navigationTitle("Review")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Retake") { onRetake() }
                        .foregroundColor(.orange)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                        onSave()
                    }
                }
            }
        }
        .sheet(isPresented: $showingShare) {
            if let image = image {
                ActivityView(activityItems: [image])
            } else if let url = videoURL {
                ActivityView(activityItems: [url])
            }
        }
    }
}

struct ReviewView_Previews: PreviewProvider {
    static var previews: some View {
        ReviewView(
            image: .constant(UIImage(systemName: "photo")),
            videoURL: .constant(nil),
            isPresented: .constant(true),
            onSave: {},
            onRetake: {}
        )
    }
}

// MARK: - Activity view wrapper

struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Video preview (simple)

import AVKit

struct VideoPreviewView: View {
    let url: URL
    var body: some View {
        VideoPlayerView(url: url)
    }
}

struct VideoPlayerView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = AVPlayer(url: url)
        return controller
    }
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {}
}
