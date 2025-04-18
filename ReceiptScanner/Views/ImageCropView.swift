import SwiftUI
import UIKit

struct ImageCropView: UIViewControllerRepresentable {
    let image: UIImage
    let onCropComplete: (UIImage?) -> Void
    
    func makeUIViewController(context: Context) -> UIImageCropViewController {
        let controller = UIImageCropViewController(image: image)
        controller.delegate = context.coordinator
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIImageCropViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImageCropViewControllerDelegate {
        let parent: ImageCropView
        
        init(_ parent: ImageCropView) {
            self.parent = parent
        }
        
        func imageCropViewControllerDidCropImage(_ controller: UIImageCropViewController, croppedImage: UIImage) {
            parent.onCropComplete(croppedImage)
            controller.dismiss(animated: true)
        }
        
        func imageCropViewControllerDidCancel(_ controller: UIImageCropViewController) {
            parent.onCropComplete(nil)
            controller.dismiss(animated: true)
        }
    }
}

// Custom UIViewController for image cropping
class UIImageCropViewController: UIViewController {
    private let imageView = UIImageView()
    private let cropOverlayView = CropOverlayView()
    private var originalImage: UIImage
    
    weak var delegate: UIImageCropViewControllerDelegate?
    
    init(image: UIImage) {
        self.originalImage = image
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    private func setupUI() {
        view.backgroundColor = .black
        
        // Setup image view
        imageView.contentMode = .scaleAspectFit
        imageView.image = originalImage
        imageView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(imageView)
        
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -100)
        ])
        
        // Setup crop overlay
        cropOverlayView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cropOverlayView)
        
        NSLayoutConstraint.activate([
            cropOverlayView.topAnchor.constraint(equalTo: imageView.topAnchor),
            cropOverlayView.leadingAnchor.constraint(equalTo: imageView.leadingAnchor),
            cropOverlayView.trailingAnchor.constraint(equalTo: imageView.trailingAnchor),
            cropOverlayView.bottomAnchor.constraint(equalTo: imageView.bottomAnchor)
        ])
        
        // Add buttons
        let buttonStack = UIStackView()
        buttonStack.axis = .horizontal
        buttonStack.distribution = .fillEqually
        buttonStack.spacing = 20
        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        
        let cancelButton = UIButton(type: .system)
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.tintColor = .white
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        
        let doneButton = UIButton(type: .system)
        doneButton.setTitle("Done", for: .normal)
        doneButton.tintColor = .white
        doneButton.addTarget(self, action: #selector(doneTapped), for: .touchUpInside)
        
        buttonStack.addArrangedSubview(cancelButton)
        buttonStack.addArrangedSubview(doneButton)
        
        view.addSubview(buttonStack)
        
        NSLayoutConstraint.activate([
            buttonStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            buttonStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            buttonStack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            buttonStack.heightAnchor.constraint(equalToConstant: 50)
        ])
    }
    
    @objc private func cancelTapped() {
        delegate?.imageCropViewControllerDidCancel(self)
    }
    
    @objc private func doneTapped() {
        // For simplicity, we'll just return the original image
        // In a real implementation, you would crop the image based on the overlay
        delegate?.imageCropViewControllerDidCropImage(self, croppedImage: originalImage)
    }
}

// Protocol for the crop view controller delegate
protocol UIImageCropViewControllerDelegate: AnyObject {
    func imageCropViewControllerDidCropImage(_ controller: UIImageCropViewController, croppedImage: UIImage)
    func imageCropViewControllerDidCancel(_ controller: UIImageCropViewController)
}

// Custom view for the crop overlay
class CropOverlayView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        
        // Draw semi-transparent overlay
        context.setFillColor(UIColor.black.withAlphaComponent(0.5).cgColor)
        context.fill(rect)
        
        // Calculate crop rect (for simplicity, we'll use a fixed rectangle in the center)
        let cropWidth = rect.width * 0.8
        let cropHeight = rect.height * 0.8
        let cropRect = CGRect(
            x: (rect.width - cropWidth) / 2,
            y: (rect.height - cropHeight) / 2,
            width: cropWidth,
            height: cropHeight
        )
        
        // Clear the crop area
        context.setBlendMode(.clear)
        context.setFillColor(UIColor.clear.cgColor)
        context.fill(cropRect)
        
        // Draw crop border
        context.setBlendMode(.normal)
        context.setStrokeColor(UIColor.white.cgColor)
        context.setLineWidth(2)
        context.stroke(cropRect)
        
        // Draw corner handles
        let handleSize: CGFloat = 20
        let handleLineWidth: CGFloat = 3
        
        // Top left
        drawCornerHandle(context: context, at: cropRect.origin, size: handleSize, lineWidth: handleLineWidth)
        
        // Top right
        drawCornerHandle(context: context, at: CGPoint(x: cropRect.maxX, y: cropRect.minY), size: handleSize, lineWidth: handleLineWidth)
        
        // Bottom left
        drawCornerHandle(context: context, at: CGPoint(x: cropRect.minX, y: cropRect.maxY), size: handleSize, lineWidth: handleLineWidth)
        
        // Bottom right
        drawCornerHandle(context: context, at: CGPoint(x: cropRect.maxX, y: cropRect.maxY), size: handleSize, lineWidth: handleLineWidth)
    }
    
    private func drawCornerHandle(context: CGContext, at point: CGPoint, size: CGFloat, lineWidth: CGFloat) {
        context.setStrokeColor(UIColor.white.cgColor)
        context.setLineWidth(lineWidth)
        
        // Horizontal line
        context.move(to: CGPoint(x: point.x, y: point.y))
        context.addLine(to: CGPoint(x: point.x + size, y: point.y))
        
        // Vertical line
        context.move(to: CGPoint(x: point.x, y: point.y))
        context.addLine(to: CGPoint(x: point.x, y: point.y + size))
        
        context.strokePath()
    }
}
