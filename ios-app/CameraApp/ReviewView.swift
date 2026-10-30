import SwiftUI

/// Post-capture review: preview the styled photo and save or dismiss.
/// From-scratch implementation.
struct ReviewView: View {
    let image: UIImage
    let onDismiss: () -> Void
    let onSave: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 300)
                .background(Color.black)
                .cornerRadius(12)
                .padding(20)

            VStack(spacing: 16) {
                HStack(spacing: 20) {
                    Button("Discard", action: onDismiss)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.black.opacity(0.5))
                        .clipShape(Capsule())

                    Button("Save", action: onSave)
                        .font(.headline)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.white)
                        .clipShape(Capsule())
                }
                .padding(.horizontal, 24)

                Button("Retake", action: onDismiss)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(.bottom, 24)
            }
        }
        .background(Color.black.ignoresSafeArea())
    }
}

struct ReviewView_Previews: PreviewProvider {
    static var previews: some View {
        ReviewView(image: UIImage(systemName: "photo") ?? UIImage(),
                   onDismiss: {}, onSave: {})
    }
}
