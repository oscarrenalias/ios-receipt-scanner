import SwiftUI
import UIKit
import Vision

struct ImageCropView: View {
    let image: UIImage
    let initialCropRect: CGRect?
    let completion: (UIImage?, CGRect?) -> Void
    
    @State private var cropRect: CGRect = .zero
    @State private var viewSize: CGSize = .zero
    @State private var imageSize: CGSize = .zero
    @State private var imageFrame: CGRect = .zero
    @State private var isDragging: Bool = false
    @State private var dragStart: CGPoint = .zero
    @State private var rectStart: CGRect = .zero
    @State private var isProcessing: Bool = true // Show overlay by default
    @Environment(\.presentationMode) var presentationMode
    
    // Corner control size
    private let cornerSize: CGFloat = 44
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.edgesIgnoringSafeArea(.all)
                
                // Image and overlay in a ZStack, overlay absolutely positioned over imageFrame
                ZStack(alignment: .topLeading) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .background(
                            GeometryReader { imageGeometry in
                                Color.clear
                                    .onAppear {
                                        let frame = imageGeometry.frame(in: .local)
                                        print("🔍 imageFrame onAppear: \(frame)")
                                        imageFrame = frame
                                        viewSize = geometry.size
                                        imageSize = CGSize(width: frame.width, height: frame.height)
                                        if cropRect == .zero && frame.width > 0 && frame.height > 0 {
                                            if let initialCropRect = initialCropRect {
                                                let scaleX = frame.width / image.size.width
                                                let scaleY = frame.height / image.size.height
                                                let cropX = frame.minX + initialCropRect.minX * scaleX
                                                let cropY = frame.minY + initialCropRect.minY * scaleY
                                                let cropWidth = initialCropRect.width * scaleX
                                                let cropHeight = initialCropRect.height * scaleY
                                                cropRect = CGRect(x: cropX, y: cropY, width: cropWidth, height: cropHeight)
                                            } else {
                                                let cropWidth = frame.width * 0.8
                                                let cropHeight = frame.height * 0.8
                                                let cropX = frame.minX + (frame.width - cropWidth) / 2
                                                let cropY = frame.minY + (frame.height - cropHeight) / 2
                                                cropRect = CGRect(x: cropX, y: cropY, width: cropWidth, height: cropHeight)
                                            }
                                            print("🔍 cropRect initialized: \(cropRect)")
                                        }
                                    }
                            }
                        )
                    // Overlay absolutely positioned over the imageFrame
                    if imageFrame.width > 0 && imageFrame.height > 0 && cropRect.width > 0 && cropRect.height > 0 {
                        CropOverlayView(
                            rect: $cropRect,
                            imageFrame: imageFrame,
                            cornerSize: cornerSize,
                            isDragging: $isDragging,
                            dragStart: $dragStart,
                            rectStart: $rectStart
                        )
                        .frame(width: imageFrame.width, height: imageFrame.height)
                        .offset(x: imageFrame.minX, y: imageFrame.minY)
                        .allowsHitTesting(true)
                    }
                }
                
                // Top toolbar
                VStack {
                    HStack {
                        Button(action: {
                            // Cancel cropping
                            print("🔍 Crop cancelled")
                            presentationMode.wrappedValue.dismiss()
                            completion(nil, nil)
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                                .padding(8)
                                .background(Color.gray.opacity(0.6))
                                .clipShape(Circle())
                        }
                        .padding(.leading)
                        
                        Spacer()
                    }
                    .padding(.top, 10)
                    
                    Spacer()
                    
                    // Bottom toolbar
                    HStack {
                        Spacer()
                        
                        Button(action: {
                            // Perform cropping
                            performCrop()
                        }) {
                            Text("Crop")
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(Color.blue)
                                .cornerRadius(8)
                        }
                        .padding(.trailing)
                    }
                    .padding(.bottom, 20)
                }
                
                // Overlay for processing indicator
                if isProcessing {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            VStack {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(1.5)
                                Text("Processing...")
                                    .foregroundColor(.white)
                                    .padding(.top, 8)
                            }
                            Spacer()
                        }
                        Spacer()
                    }
                    .background(Color.black.opacity(0.7))
                    .edgesIgnoringSafeArea(.all)
                }
            }
            //.ignoresSafeArea() // Ensure the crop view takes up the full screen
        }
        .navigationBarHidden(true)
        .statusBar(hidden: true)
        .background(Color.black) // Ensure full black background
        .onAppear {
            // Only run edge detection if this is the first crop (no initialCropRect)
            if initialCropRect == nil {
                detectDocumentEdges()
            } else {
                isProcessing = false // No need to show overlay
            }
        }
    }
    
    private func performCrop() {
        print("🔍 Performing crop with rect: \(cropRect)")
        
        // Normalize image orientation to .up before cropping
        let normalizedImage = image.normalizedToUpOrientation()
        
        // Convert crop rect from display coordinates to image coordinates
        let imageDisplayFrame = imageFrame
        let scaleX = normalizedImage.size.width / imageDisplayFrame.width
        let scaleY = normalizedImage.size.height / imageDisplayFrame.height
        let cropX = (cropRect.minX - imageDisplayFrame.minX) * scaleX
        let cropY = (cropRect.minY - imageDisplayFrame.minY) * scaleY
        let cropWidth = cropRect.width * scaleX
        let cropHeight = cropRect.height * scaleY
        let imageCropRect = CGRect(x: cropX, y: cropY, width: cropWidth, height: cropHeight)
        print("🔍 Image crop rect: \(imageCropRect)")
        print("🔍 Normalized image size: \(normalizedImage.size.width) x \(normalizedImage.size.height)")
        let validCropRect = CGRect(
            x: max(0, min(imageCropRect.minX, normalizedImage.size.width - 1)),
            y: max(0, min(imageCropRect.minY, normalizedImage.size.height - 1)),
            width: min(imageCropRect.width, normalizedImage.size.width - imageCropRect.minX),
            height: min(imageCropRect.height, normalizedImage.size.height - imageCropRect.minY)
        )
        print("🔍 Valid crop rect: \(validCropRect)")
        if let cgImage = normalizedImage.cgImage?.cropping(to: validCropRect) {
            let croppedImage = UIImage(cgImage: cgImage, scale: normalizedImage.scale, orientation: .up)
            print("🔍 Cropping successful, new image size: \(croppedImage.size.width) x \(croppedImage.size.height)")
            presentationMode.wrappedValue.dismiss()
            completion(croppedImage, validCropRect)
        } else {
            print("❌ Cropping failed")
            presentationMode.wrappedValue.dismiss()
            completion(nil, nil)
        }
    }
    
    private func detectDocumentEdges() {
        isProcessing = true
        DispatchQueue.global(qos: .userInitiated).async {
            guard let cgImage = image.cgImage else {
                DispatchQueue.main.async {
                    print("❌ Vision: Could not get CGImage from UIImage")
                    isProcessing = false
                }
                return
            }
            let request = VNDetectRectanglesRequest { request, error in
                DispatchQueue.main.async {
                    defer { isProcessing = false }
                    if let error = error {
                        print("❌ Vision: VNDetectRectanglesRequest failed: \(error.localizedDescription)")
                        setDefaultCropRect()
                        return
                    }
                    guard let results = request.results as? [VNRectangleObservation], let rect = results.first else {
                        print("ℹ️ Vision: No rectangles detected, falling back to default crop rect.")
                        setDefaultCropRect()
                        return
                    }
                    print("✅ Vision: Detected rectangle: ")
                    print("  topLeft:     \(rect.topLeft)")
                    print("  topRight:    \(rect.topRight)")
                    print("  bottomLeft:  \(rect.bottomLeft)")
                    print("  bottomRight: \(rect.bottomRight)")
                    print("  boundingBox: \(rect.boundingBox)")
                    setCropRect(from: rect)
                }
            }
            // Configure request for documents (more permissive)
            request.minimumAspectRatio = 0.2
            request.maximumAspectRatio = 1.0
            request.minimumSize = 0.05
            request.minimumConfidence = 0.2
            request.quadratureTolerance = 45.0
            request.maximumObservations = 1
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                DispatchQueue.main.async {
                    setDefaultCropRect()
                    isProcessing = false
                }
            }
        }
    }

    private func setDefaultCropRect() {
        // Use the same logic as before for default 80% rectangle
        if let frame = getImageFrame(), cropRect == .zero {
            let cropWidth = frame.width * 0.8
            let cropHeight = frame.height * 0.8
            let cropX = frame.minX + (frame.width - cropWidth) / 2
            let cropY = frame.minY + (frame.height - cropHeight) / 2
            cropRect = CGRect(x: cropX, y: cropY, width: cropWidth, height: cropHeight)
        }
    }

    private func setCropRect(from observation: VNRectangleObservation) {
        guard let frame = getImageFrame() else { return }
        // VNRectangleObservation provides normalized coordinates (0,0) is bottom-left
        // Convert to image coordinates, then to displayed frame
        let imageWidth = image.size.width
        let imageHeight = image.size.height
        func convert(_ point: CGPoint) -> CGPoint {
            // Convert normalized Vision point to image pixel coordinates
            CGPoint(x: point.x * imageWidth, y: (1 - point.y) * imageHeight)
        }
        let tl = convert(observation.topLeft)
        let tr = convert(observation.topRight)
        let bl = convert(observation.bottomLeft)
        let br = convert(observation.bottomRight)
        // Bounding box in image coordinates
        let minX = min(tl.x, tr.x, bl.x, br.x)
        let maxX = max(tl.x, tr.x, bl.x, br.x)
        let minY = min(tl.y, tr.y, bl.y, br.y)
        let maxY = max(tl.y, tr.y, bl.y, br.y)
        let rectInImage = CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
        // Map to displayed frame
        let scaleX = frame.width / imageWidth
        let scaleY = frame.height / imageHeight
        let cropX = frame.minX + rectInImage.minX * scaleX
        let cropY = frame.minY + rectInImage.minY * scaleY
        let cropWidth = rectInImage.width * scaleX
        let cropHeight = rectInImage.height * scaleY
        cropRect = CGRect(x: cropX, y: cropY, width: cropWidth, height: cropHeight)
    }

    private func getImageFrame() -> CGRect? {
        // Helper to get the current imageFrame (used in main thread)
        if imageFrame.width > 0 && imageFrame.height > 0 {
            return imageFrame
        }
        return nil
    }
}

// Preference key to get the image frame
struct ImageFramePreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

struct CropOverlayView: View {
    @Binding var rect: CGRect
    let imageFrame: CGRect
    let cornerSize: CGFloat
    @Binding var isDragging: Bool
    @Binding var dragStart: CGPoint
    @Binding var rectStart: CGRect
    @State private var activeCorner: Corner? = nil
    @State private var cornerDragStart: CGPoint = .zero
    @State private var cornerRectStart: CGRect = .zero
    
    enum Corner: Hashable {
        case topLeft, topRight, bottomLeft, bottomRight
    }
    
    var body: some View {
        ZStack {
            // Semi-transparent overlay outside crop area
            Rectangle()
                .fill(Color.black.opacity(0.5))
                .mask(
                    Rectangle()
                        .frame(width: imageFrame.width, height: imageFrame.height)
                        .position(x: imageFrame.midX, y: imageFrame.midY)
                        .overlay(
                            Rectangle()
                                .frame(width: rect.width, height: rect.height)
                                .position(x: rect.midX, y: rect.midY)
                                .blendMode(.destinationOut)
                        )
                )
            
            // Crop rectangle border
            Rectangle()
                .stroke(Color.white, lineWidth: 1)
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)
                // Make the entire rectangle draggable, but only if no corner is being dragged
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            // Only allow rectangle dragging if no corner is active
                            if activeCorner == nil {
                                if !isDragging {
                                    isDragging = true
                                    dragStart = value.location
                                    rectStart = rect
                                    print("🔍 Started dragging rectangle at \(dragStart)")
                                }
                                
                                let translation = CGPoint(
                                    x: value.location.x - dragStart.x,
                                    y: value.location.y - dragStart.y
                                )
                                
                                // Calculate new rect position
                                var newRect = rectStart
                                newRect.origin.x += translation.x
                                newRect.origin.y += translation.y
                                
                                // Constrain to image bounds
                                if newRect.minX < imageFrame.minX {
                                    newRect.origin.x = imageFrame.minX
                                }
                                if newRect.maxX > imageFrame.maxX {
                                    newRect.origin.x = imageFrame.maxX - newRect.width
                                }
                                if newRect.minY < imageFrame.minY {
                                    newRect.origin.y = imageFrame.minY
                                }
                                if newRect.maxY > imageFrame.maxY {
                                    newRect.origin.y = imageFrame.maxY - newRect.height
                                }
                                
                                rect = newRect
                            }
                        }
                        .onEnded { _ in
                            isDragging = false
                            print("🔍 Finished dragging rectangle")
                        }
                )
            
            // Corner controls - make them larger and more visible
            Group {
                // Top-left corner
                cornerControl(at: CGPoint(x: rect.minX, y: rect.minY), corner: .topLeft)
                
                // Top-right corner
                cornerControl(at: CGPoint(x: rect.maxX, y: rect.minY), corner: .topRight)
                
                // Bottom-left corner
                cornerControl(at: CGPoint(x: rect.minX, y: rect.maxY), corner: .bottomLeft)
                
                // Bottom-right corner
                cornerControl(at: CGPoint(x: rect.maxX, y: rect.maxY), corner: .bottomRight)
            }
        }
    }
    
    @ViewBuilder
    private func cornerControl(at position: CGPoint, corner: Corner) -> some View {
        // Make corners more visible with a larger touch area
        ZStack {
            // Larger transparent touch area
            Circle()
                .fill(Color.white.opacity(0.001)) // Nearly invisible but still detectable for touch
                .frame(width: cornerSize * 2, height: cornerSize * 2)
            
            // Visible corner indicator
            Circle()
                .fill(Color.white)
                .frame(width: cornerSize / 2, height: cornerSize / 2)
                .overlay(
                    Circle()
                        .stroke(Color.black, lineWidth: 1)
                )
        }
        .position(position)
        .highPriorityGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    if activeCorner != corner {
                        activeCorner = corner
                        cornerDragStart = value.startLocation
                        cornerRectStart = rect
                    }
                    updateRect(for: corner, with: value.location, dragStart: cornerDragStart, rectStart: cornerRectStart)
                }
                .onEnded { _ in
                    activeCorner = nil
                }
        )
    }
    
    private func updateRect(for corner: Corner, with location: CGPoint, dragStart: CGPoint, rectStart: CGRect) {
        var newRect = rectStart
        // Calculate translation from drag start
        let dx = location.x - dragStart.x
        let dy = location.y - dragStart.y
        switch corner {
        case .topLeft:
            let newX = max(imageFrame.minX, min(rectStart.maxX - 50, rectStart.origin.x + dx))
            let newY = max(imageFrame.minY, min(rectStart.maxY - 50, rectStart.origin.y + dy))
            newRect.origin.x = newX
            newRect.origin.y = newY
            newRect.size.width = rectStart.maxX - newX
            newRect.size.height = rectStart.maxY - newY
        case .topRight:
            let newWidth = max(50, min(imageFrame.maxX - rectStart.minX, rectStart.width + dx))
            let newY = max(imageFrame.minY, min(rectStart.maxY - 50, rectStart.origin.y + dy))
            newRect.size.width = newWidth
            newRect.origin.y = newY
            newRect.size.height = rectStart.maxY - newY
        case .bottomLeft:
            let newX = max(imageFrame.minX, min(rectStart.maxX - 50, rectStart.origin.x + dx))
            let newHeight = max(50, min(imageFrame.maxY - rectStart.minY, rectStart.height + dy))
            newRect.origin.x = newX
            newRect.size.width = rectStart.maxX - newX
            newRect.size.height = newHeight
        case .bottomRight:
            let newWidth = max(50, min(imageFrame.maxX - rectStart.minX, rectStart.width + dx))
            let newHeight = max(50, min(imageFrame.maxY - rectStart.minY, rectStart.height + dy))
            newRect.size.width = newWidth
            newRect.size.height = newHeight
        }
        // Constrain to image bounds
        if newRect.minX < imageFrame.minX { newRect.origin.x = imageFrame.minX }
        if newRect.maxX > imageFrame.maxX { newRect.size.width = imageFrame.maxX - newRect.minX }
        if newRect.minY < imageFrame.minY { newRect.origin.y = imageFrame.minY }
        if newRect.maxY > imageFrame.maxY { newRect.size.height = imageFrame.maxY - newRect.minY }
        rect = newRect
    }
}

// MARK: - UIImage Orientation Normalization Helper
private extension UIImage {
    func normalizedToUpOrientation() -> UIImage {
        if imageOrientation == .up {
            return self
        }
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        defer { UIGraphicsEndImageContext() }
        draw(in: CGRect(origin: .zero, size: size))
        return UIGraphicsGetImageFromCurrentImageContext() ?? self
    }
}
