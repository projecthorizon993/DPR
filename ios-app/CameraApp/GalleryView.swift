//
//  GalleryView.swift
//  CameraApp
//
//  Simple gallery of last captured media.
//

import SwiftUI

struct GalleryView: View {
    @ObservedObject var viewModel: CameraViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            VStack {
                if let thumb = viewModel.lastThumbnail {
                    Image(uiImage: thumb)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding()
                } else {
                    Text("No photos yet")
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Gallery")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

struct GalleryView_Previews: PreviewProvider {
    static var previews: some View {
        GalleryView(viewModel: CameraViewModel())
    }
}
