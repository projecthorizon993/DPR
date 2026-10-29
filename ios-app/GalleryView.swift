//
//  GalleryView.swift
//  CameraApp
//

import SwiftUI

struct GalleryView: View {
    @ObservedObject var viewModel: CameraService

    var body: some View {
        NavigationView {
            Text("Gallery")
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
            .navigationTitle("Gallery")
            .preferredColorScheme(.dark)
        }
    }
}
