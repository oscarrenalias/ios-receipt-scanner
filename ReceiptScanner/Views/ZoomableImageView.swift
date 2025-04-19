import SwiftUI
import UIKit

struct ZoomableImageView: UIViewRepresentable {
    let image: UIImage
    
    func makeUIView(context: Context) -> UIScrollView {
        // Create the scroll view
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.maximumZoomScale = 4.0
        scrollView.minimumZoomScale = 1.0
        scrollView.bouncesZoom = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        
        // Create the image view
        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.tag = 100
        
        // Add the image view to the scroll view
        scrollView.addSubview(imageView)
        
        // Add constraints to center the image view in the scroll view
        NSLayoutConstraint.activate([
            imageView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            imageView.heightAnchor.constraint(equalTo: scrollView.heightAnchor),
            imageView.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: scrollView.centerYAnchor)
        ])
        
        // Add double tap gesture for zoom
        let doubleTapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDoubleTap(_:)))
        doubleTapGesture.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTapGesture)
        
        return scrollView
    }
    
    func updateUIView(_ uiView: UIScrollView, context: Context) {
        // Update the image when it changes
        if let imageView = uiView.viewWithTag(100) as? UIImageView {
            imageView.image = image
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIScrollViewDelegate {
        let parent: ZoomableImageView
        
        init(_ parent: ZoomableImageView) {
            self.parent = parent
        }
        
        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            return scrollView.viewWithTag(100)
        }
        
        @objc func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
            guard let scrollView = gesture.view as? UIScrollView else { return }
            
            if scrollView.zoomScale > scrollView.minimumZoomScale {
                // If zoomed in, zoom out
                scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
            } else {
                // If zoomed out, zoom in to where the user tapped
                let location = gesture.location(in: scrollView)
                let zoomRect = CGRect(
                    x: location.x - 50,
                    y: location.y - 50,
                    width: 100,
                    height: 100
                )
                scrollView.zoom(to: zoomRect, animated: true)
            }
        }
    }
}
