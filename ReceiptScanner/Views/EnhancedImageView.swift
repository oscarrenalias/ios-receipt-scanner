import SwiftUI
import SDWebImageSwiftUI

struct EnhancedImageView: View {
    let imageURL: URL?
    let placeholderImage: UIImage
    
    @State private var isLoading = false
    
    var body: some View {
        ZStack {
            if let imageURL = imageURL {
                WebImage(url: imageURL)
                    .onSuccess { _, _, _ in
                        isLoading = false
                    }
                    .resizable()
                    .indicator { _, _ in
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    }
                    .transition(AnyTransition.opacity.animation(.easeInOut(duration: 0.5)))
                    .scaledToFit()
            } else {
                Image(uiImage: placeholderImage)
                    .resizable()
                    .scaledToFit()
            }
        }
    }
}
