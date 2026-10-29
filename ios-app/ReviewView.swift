//
//  ReviewView.swift
//  CameraApp
//

import SwiftUI

struct ReviewView: View {
    @Binding var image: UIImage?
    @Binding var videoURL: URL?
    @Binding var isPresented: Bool
    let onSave: () -> Void
    let onRetake: () -> Void

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                }
            }
            .navigationTitle("Review")
            .navigationBarItems(
                leading: Button("Retake") {
                    onRetake()
                    isPresented = false
                },
                trailing: Button("Save") {
                    onSave()
                    isPresented = false
                }
            )
            .preferredColorScheme(.dark)
        }
    }
}
