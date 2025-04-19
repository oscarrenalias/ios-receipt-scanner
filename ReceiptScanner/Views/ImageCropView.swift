import SwiftUI
import UIKit
import AVFoundation

struct ImageCropView: View {
    let image: UIImage
    let onCropComplete: (UIImage?) -> Void
    
    init(image: UIImage, onCropComplete: @escaping (UIImage?) -> Void) {
        self.image = image
        self.onCropComplete = onCropComplete
        print("🔍 ImageCropView initialized with image: \(image.size.width) x \(image.size.height)")
    }
    
    var body: some View {
        ImageCropperRepresentable(image: image, onCropComplete: onCropComplete)
            .edgesIgnoringSafeArea(.all)
            .onAppear {
                print("🔍 ImageCropView appeared with image dimensions: \(image.size.width) x \(image.size.height)")
            }
    }
}

struct ImageCropperRepresentable: UIViewControllerRepresentable {
    let image: UIImage
    let onCropComplete: (UIImage?) -> Void
    
    init(image: UIImage, onCropComplete: @escaping (UIImage?) -> Void) {
        self.image = image
        self.onCropComplete = onCropComplete
        print("🔍 ImageCropperRepresentable initialized")
    }
    
    func makeUIViewController(context: Context) -> UIImageCropperViewController {
        print("🔍 Creating UIImageCropperViewController")
        let controller = UIImageCropperViewController(image: image)
        controller.delegate = context.coordinator
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIImageCropperViewController, context: Context) {
        print("🔍 Updating UIImageCropperViewController")
    }
    
    func makeCoordinator() -> Coordinator {
        print("🔍 Creating Coordinator")
        return Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImageCropperViewControllerDelegate {
        let parent: ImageCropperRepresentable
        
        init(_ parent: ImageCropperRepresentable) {
            self.parent = parent
            super.init()
            print("🔍 Coordinator initialized")
        }
        
        func imageCropperViewController(_ controller: UIImageCropperViewController, didFinishCroppingImage image: UIImage) {
            print("🔍 Coordinator received cropped image with dimensions: \(image.size.width) x \(image.size.height)")
            parent.onCropComplete(image)
        }
        
        func imageCropperViewControllerDidCancel(_ controller: UIImageCropperViewController) {
            print("🔍 Coordinator received cancel event")
            parent.onCropComplete(nil)
        }
    }
}

protocol UIImageCropperViewControllerDelegate: AnyObject {
    func imageCropperViewController(_ controller: UIImageCropperViewController, didFinishCroppingImage image: UIImage)
    func imageCropperViewControllerDidCancel(_ controller: UIImageCropperViewController)
}

class UIImageCropperViewController: UIViewController {
    weak var delegate: UIImageCropperViewControllerDelegate?
    private let imageView = UIImageView()
    private let scrollView = UIScrollView()
    private let cropOverlayView = CropOverlayView()
    private let originalImage: UIImage
    
    // UI elements
    private let topBar = UIView()
    private let bottomBar = UIView()
    private var cancelButton = UIButton(type: .system)
    private var doneButton = UIButton(type: .system)
    
    // For tracking zoom and pan
    private var currentZoomScale: CGFloat = 1.0
    private var currentContentOffset: CGPoint = .zero
    
    init(image: UIImage) {
        self.originalImage = image
        super.init(nibName: nil, bundle: nil)
        print("🔍 UIImageCropperViewController initializing with image: \(image.size.width) x \(image.size.height)")
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        print("🔍 UIImageCropperViewController viewDidLoad")
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateCropOverlayFrame()
        print("🔍 UIImageCropperViewController viewDidLayoutSubviews")
    }
    
    private func setupUI() {
        view.backgroundColor = .black
        
        // Setup scroll view
        scrollView.delegate = self
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.alwaysBounceVertical = true
        scrollView.alwaysBounceHorizontal = true
        scrollView.clipsToBounds = false
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.bouncesZoom = true
        view.addSubview(scrollView)
        
        // Setup image view
        imageView.image = originalImage
        imageView.contentMode = .scaleAspectFit
        scrollView.addSubview(imageView)
        
        // Setup crop overlay
        cropOverlayView.backgroundColor = .clear
        view.addSubview(cropOverlayView)
        
        // Setup top bar
        topBar.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        view.addSubview(topBar)
        
        // Setup bottom bar
        bottomBar.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        view.addSubview(bottomBar)
        
        // Setup buttons
        let buttonStack = UIStackView()
        buttonStack.axis = .horizontal
        buttonStack.distribution = .equalSpacing
        buttonStack.alignment = .center
        bottomBar.addSubview(buttonStack)
        
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.tintColor = .white
        cancelButton.titleLabel?.font = UIFont.systemFont(ofSize: 18)
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        
        doneButton.setTitle("CROP IMAGE", for: .normal)
        doneButton.tintColor = .white
        doneButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        doneButton.addTarget(self, action: #selector(doneTapped), for: .touchUpInside)
        
        buttonStack.addArrangedSubview(cancelButton)
        buttonStack.addArrangedSubview(doneButton)
        
        // Add double tap gesture for zoom
        let doubleTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTapGesture.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTapGesture)
        
        // Layout constraints
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        imageView.translatesAutoresizingMaskIntoConstraints = false
        cropOverlayView.translatesAutoresizingMaskIntoConstraints = false
        topBar.translatesAutoresizingMaskIntoConstraints = false
        bottomBar.translatesAutoresizingMaskIntoConstraints = false
        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            topBar.topAnchor.constraint(equalTo: view.topAnchor),
            topBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            topBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            topBar.heightAnchor.constraint(equalToConstant: 44 + (UIApplication.shared.windows.first?.safeAreaInsets.top ?? 0)),
            
            bottomBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            bottomBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomBar.heightAnchor.constraint(equalToConstant: 64 + (UIApplication.shared.windows.first?.safeAreaInsets.bottom ?? 0)),
            
            buttonStack.centerXAnchor.constraint(equalTo: bottomBar.centerXAnchor),
            buttonStack.topAnchor.constraint(equalTo: bottomBar.topAnchor, constant: 8),
            buttonStack.widthAnchor.constraint(equalTo: bottomBar.widthAnchor, constant: -32),
            
            scrollView.topAnchor.constraint(equalTo: topBar.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomBar.topAnchor)
        ])
        
        // Initial setup for image view and scroll view
        updateImageViewAndScrollView()
    }
    
    private func updateImageViewAndScrollView() {
        // Reset zoom scale
        scrollView.zoomScale = 1.0
        currentZoomScale = 1.0
        
        // Calculate the frame that will fit the image with aspect ratio
        let imageSize = originalImage.size
        let scrollViewSize = scrollView.bounds.size
        
        let widthRatio = scrollViewSize.width / imageSize.width
        let heightRatio = scrollViewSize.height / imageSize.height
        
        // Use the smaller ratio to ensure the entire image fits
        let minRatio = min(widthRatio, heightRatio)
        
        // Set the image view's frame
        let scaledWidth = imageSize.width * minRatio
        let scaledHeight = imageSize.height * minRatio
        
        imageView.frame = CGRect(
            x: (scrollViewSize.width - scaledWidth) / 2,
            y: (scrollViewSize.height - scaledHeight) / 2,
            width: scaledWidth,
            height: scaledHeight
        )
        
        // Set the content size to match the image view
        scrollView.contentSize = imageView.frame.size
        
        // Set min/max zoom scales
        scrollView.minimumZoomScale = minRatio * 0.5 // Allow zooming out to see more context
        scrollView.maximumZoomScale = minRatio * 3.0 // Allow zooming in for detail
        
        // Start with the image fitting the screen
        scrollView.zoomScale = minRatio
        
        // Center the image in the scroll view
        updateScrollViewContentInset()
        
        print("🔍 Image view frame: \(imageView.frame)")
        print("🔍 Scroll view content size: \(scrollView.contentSize)")
        print("🔍 Min zoom scale: \(scrollView.minimumZoomScale), Max zoom scale: \(scrollView.maximumZoomScale)")
        print("🔍 Initial zoom scale: \(scrollView.zoomScale)")
    }
    
    private func updateScrollViewContentInset() {
        let imageViewSize = imageView.frame.size
        let scrollViewSize = scrollView.bounds.size
        
        let verticalInset = max(0, (scrollViewSize.height - imageViewSize.height) / 2)
        let horizontalInset = max(0, (scrollViewSize.width - imageViewSize.width) / 2)
        
        scrollView.contentInset = UIEdgeInsets(
            top: verticalInset,
            left: horizontalInset,
            bottom: verticalInset,
            right: horizontalInset
        )
    }
    
    private func updateCropOverlayFrame() {
        // The crop overlay should match the scroll view's frame
        cropOverlayView.frame = scrollView.frame
        cropOverlayView.setNeedsDisplay()
    }
    
    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        if scrollView.zoomScale > scrollView.minimumZoomScale {
            // If zoomed in, zoom out to minimum
            scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
        } else {
            // If zoomed out, zoom in to a higher level
            let location = gesture.location(in: imageView)
            let zoomRect = CGRect(
                x: location.x - 50,
                y: location.y - 50,
                width: 100,
                height: 100
            )
            scrollView.zoom(to: zoomRect, animated: true)
        }
    }
    
    @objc private func cancelTapped() {
        print("🔍 Cancel button tapped")
        delegate?.imageCropperViewControllerDidCancel(self)
        dismiss(animated: true)
    }
    
    @objc private func doneTapped() {
        print("🔍 Crop button tapped")
        // Get the crop rect in normalized coordinates (0-1)
        let normalizedCropRect = cropOverlayView.normalizedCropRect
        
        // Get the original image dimensions
        let imageWidth = CGFloat(originalImage.cgImage?.width ?? 0)
        let imageHeight = CGFloat(originalImage.cgImage?.height ?? 0)
        
        // Log start of crop operation
        print("🔍 Starting crop operation")
        print("🔍 Original image dimensions: \(imageWidth) x \(imageHeight)")
        print("🔍 Current zoom: \(currentZoomScale), offset: (\(currentContentOffset.x), \(currentContentOffset.y))")
        
        // Direct conversion from normalized to pixel coordinates
        let pixelCropRect = CGRect(
            x: normalizedCropRect.origin.x * imageWidth,
            y: normalizedCropRect.origin.y * imageHeight,
            width: normalizedCropRect.width * imageWidth,
            height: normalizedCropRect.height * imageHeight
        )
        
        // Ensure integer coordinates to avoid rounding issues
        let intPixelCropRect = CGRect(
            x: floor(pixelCropRect.origin.x),
            y: floor(pixelCropRect.origin.y),
            width: ceil(pixelCropRect.width),
            height: ceil(pixelCropRect.height)
        )
        
        // Ensure the crop rect is within the image bounds
        let imageBounds = CGRect(origin: .zero, size: CGSize(width: imageWidth, height: imageHeight))
        let validCropRect = intPixelCropRect.intersection(imageBounds)
        
        // Log detailed information for debugging
        print("🔍 Normalized crop rect: \(normalizedCropRect)")
        print("🔍 Pixel crop rect: \(pixelCropRect)")
        print("🔍 Valid crop rect: \(validCropRect)")
        
        // Create cropped image
        if let cgImage = originalImage.cgImage?.cropping(to: validCropRect) {
            let croppedImage = UIImage(cgImage: cgImage)
            print("🔍 Cropped image dimensions: \(croppedImage.size.width) x \(croppedImage.size.height)")
            delegate?.imageCropperViewController(self, didFinishCroppingImage: croppedImage)
            dismiss(animated: true)
        } else {
            print("🔍 Cropping failed, returning original image")
            delegate?.imageCropperViewController(self, didFinishCroppingImage: originalImage)
            dismiss(animated: true)
        }
    }
}

// MARK: - UIScrollViewDelegate
extension UIImageCropperViewController: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return imageView
    }
    
    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        updateScrollViewContentInset()
        currentZoomScale = scrollView.zoomScale
        print("🔍 Zoom scale changed to: \(currentZoomScale)")
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        currentContentOffset = scrollView.contentOffset
    }
}

// MARK: - CropOverlayView
class CropOverlayView: UIView {
    private let cropRectInset: CGFloat = 20
    private var cropRect: CGRect = .zero
    
    // Normalized crop rect (0-1 coordinates)
    var normalizedCropRect: CGRect {
        guard bounds.width > 0 && bounds.height > 0 else { return CGRect(x: 0, y: 0, width: 1, height: 1) }
        
        return CGRect(
            x: (cropRect.origin.x - cropRectInset) / bounds.width,
            y: (cropRect.origin.y - cropRectInset) / bounds.height,
            width: cropRect.width / bounds.width,
            height: cropRect.height / bounds.height
        )
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isUserInteractionEnabled = false
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        updateCropRect()
    }
    
    private func updateCropRect() {
        let minDimension = min(bounds.width, bounds.height) - (cropRectInset * 2)
        let size = CGSize(width: minDimension, height: minDimension)
        
        cropRect = CGRect(
            x: (bounds.width - size.width) / 2 + cropRectInset,
            y: (bounds.height - size.height) / 2 + cropRectInset,
            width: size.width - (cropRectInset * 2),
            height: size.height - (cropRectInset * 2)
        )
        
        setNeedsDisplay()
    }
    
    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        
        // Draw semi-transparent overlay
        context.setFillColor(UIColor.black.withAlphaComponent(0.5).cgColor)
        context.fill(rect)
        
        // Clear the crop rect area
        context.setBlendMode(.clear)
        context.fill(cropRect)
        
        // Reset blend mode
        context.setBlendMode(.normal)
        
        // Draw crop rect border
        context.setStrokeColor(UIColor.white.cgColor)
        context.setLineWidth(1.0)
        context.stroke(cropRect)
        
        // Draw grid lines
        context.setStrokeColor(UIColor.white.withAlphaComponent(0.5).cgColor)
        context.setLineWidth(0.5)
        
        // Vertical lines
        let thirdWidth = cropRect.width / 3
        context.move(to: CGPoint(x: cropRect.minX + thirdWidth, y: cropRect.minY))
        context.addLine(to: CGPoint(x: cropRect.minX + thirdWidth, y: cropRect.maxY))
        
        context.move(to: CGPoint(x: cropRect.minX + 2 * thirdWidth, y: cropRect.minY))
        context.addLine(to: CGPoint(x: cropRect.minX + 2 * thirdWidth, y: cropRect.maxY))
        
        // Horizontal lines
        let thirdHeight = cropRect.height / 3
        context.move(to: CGPoint(x: cropRect.minX, y: cropRect.minY + thirdHeight))
        context.addLine(to: CGPoint(x: cropRect.maxX, y: cropRect.minY + thirdHeight))
        
        context.move(to: CGPoint(x: cropRect.minX, y: cropRect.minY + 2 * thirdHeight))
        context.addLine(to: CGPoint(x: cropRect.maxX, y: cropRect.minY + 2 * thirdHeight))
        
        context.strokePath()
    }
}
