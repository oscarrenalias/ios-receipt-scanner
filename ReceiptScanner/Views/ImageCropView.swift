import SwiftUI
import UIKit
import Vision

struct Quadrilateral {
    var topLeft: CGPoint
    var topRight: CGPoint
    var bottomRight: CGPoint
    var bottomLeft: CGPoint
}

struct ImageCropView: View {
    let image: UIImage
    let initialCropRect: CGRect?
    let completion: (UIImage?, CGRect?) -> Void
    
    @State private var quad: Quadrilateral = Quadrilateral(
        topLeft: .zero, topRight: .zero, bottomRight: .zero, bottomLeft: .zero
    )
    @State private var viewSize: CGSize = .zero
    @State private var imageSize: CGSize = .zero
    @State private var imageFrame: CGRect = .zero
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
                    // Always normalize image to .up for both display and cropping
                    let normalizedImage = image.normalizedToUpOrientation()
                    Image(uiImage: normalizedImage)
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
                                        if quad.topLeft == .zero && frame.width > 0 && frame.height > 0 {
                                            if let initialCropRect = initialCropRect {
                                                let scaleX = frame.width / normalizedImage.size.width
                                                let scaleY = frame.height / normalizedImage.size.height
                                                let cropX = frame.minX + initialCropRect.minX * scaleX
                                                let cropY = frame.minY + initialCropRect.minY * scaleY
                                                let cropWidth = initialCropRect.width * scaleX
                                                let cropHeight = initialCropRect.height * scaleY
                                                quad = Quadrilateral(
                                                    topLeft: CGPoint(x: cropX, y: cropY),
                                                    topRight: CGPoint(x: cropX + cropWidth, y: cropY),
                                                    bottomRight: CGPoint(x: cropX + cropWidth, y: cropY + cropHeight),
                                                    bottomLeft: CGPoint(x: cropX, y: cropY + cropHeight)
                                                )
                                            } else {
                                                let cropWidth = frame.width * 0.8
                                                let cropHeight = frame.height * 0.8
                                                let cropX = frame.minX + (frame.width - cropWidth) / 2
                                                let cropY = frame.minY + (frame.height - cropHeight) / 2
                                                quad = Quadrilateral(
                                                    topLeft: CGPoint(x: cropX, y: cropY),
                                                    topRight: CGPoint(x: cropX + cropWidth, y: cropY),
                                                    bottomRight: CGPoint(x: cropX + cropWidth, y: cropY + cropHeight),
                                                    bottomLeft: CGPoint(x: cropX, y: cropY + cropHeight)
                                                )
                                            }
                                            print("🔍 quad initialized: \(quad)")
                                        }
                                    }
                            }
                        )
                    // Overlay absolutely positioned over the imageFrame
                    if imageFrame.width > 0 && imageFrame.height > 0 && quad.topLeft != .zero && quad.topRight != .zero && quad.bottomRight != .zero && quad.bottomLeft != .zero {
                        QuadCropOverlayView(
                            quad: $quad,
                            imageFrame: imageFrame,
                            cornerSize: cornerSize
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
                        // Reset to Rectangle button
                        Button(action: {
                            resetQuadToRectangle()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.uturn.backward")
                                Text("Reset")
                            }
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Color.gray.opacity(0.7))
                            .cornerRadius(8)
                        }
                        .padding(.trailing, 8)
                        // Crop button
                        Button(action: {
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
        guard quad.topLeft != .zero else { return }
        // Use the same normalized image as displayed
        let normalizedImage = image.normalizedToUpOrientation()
        let imageDisplayFrame = imageFrame
        let scaleX = normalizedImage.size.width / imageDisplayFrame.width
        let scaleY = normalizedImage.size.height / imageDisplayFrame.height
        let points = [quad.topLeft, quad.topRight, quad.bottomRight, quad.bottomLeft].map {
            let x = ($0.x - imageDisplayFrame.minX) * scaleX
            let y = ($0.y - imageDisplayFrame.minY) * scaleY
            // Flip y for Core Image (origin is bottom-left)
            return CGPoint(x: x, y: normalizedImage.size.height - y)
        }
        if let ciImage = CIImage(image: normalizedImage) {
            let filter = CIFilter.perspectiveCorrection()
            filter.inputImage = ciImage
            filter.topLeft = points[0]
            filter.topRight = points[1]
            filter.bottomRight = points[2]
            filter.bottomLeft = points[3]
            let context = CIContext()
            if let output = filter.outputImage {
                if let cgImage = context.createCGImage(output, from: output.extent) {
                    let croppedImage = UIImage(cgImage: cgImage, scale: normalizedImage.scale, orientation: .up)
                    presentationMode.wrappedValue.dismiss()
                    completion(croppedImage, output.extent)
                    return
                }
            }
        }
        presentationMode.wrappedValue.dismiss()
        completion(nil, nil)
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
                        setDefaultQuad()
                        return
                    }
                    guard let results = request.results as? [VNRectangleObservation], let rect = results.first else {
                        print("ℹ️ Vision: No rectangles detected, falling back to default crop rect.")
                        setDefaultQuad()
                        return
                    }
                    print("✅ Vision: Detected rectangle: ")
                    print("  topLeft:     \(rect.topLeft)")
                    print("  topRight:    \(rect.topRight)")
                    print("  bottomLeft:  \(rect.bottomLeft)")
                    print("  bottomRight: \(rect.bottomRight)")
                    print("  boundingBox: \(rect.boundingBox)")
                    setQuad(from: rect)
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
                    setDefaultQuad()
                    isProcessing = false
                }
            }
        }
    }

    private func setDefaultQuad() {
        if let frame = getImageFrame(), quad.topLeft == .zero {
            let cropWidth = frame.width * 0.8
            let cropHeight = frame.height * 0.8
            let cropX = frame.minX + (frame.width - cropWidth) / 2
            let cropY = frame.minY + (frame.height - cropHeight) / 2
            quad = Quadrilateral(
                topLeft: CGPoint(x: cropX, y: cropY),
                topRight: CGPoint(x: cropX + cropWidth, y: cropY),
                bottomRight: CGPoint(x: cropX + cropWidth, y: cropY + cropHeight),
                bottomLeft: CGPoint(x: cropX, y: cropY + cropHeight)
            )
        }
    }

    private func setQuad(from observation: VNRectangleObservation) {
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
        // Map to displayed frame
        let scaleX = frame.width / imageWidth
        let scaleY = frame.height / imageHeight
        quad = Quadrilateral(
            topLeft: CGPoint(x: frame.minX + tl.x * scaleX, y: frame.minY + tl.y * scaleY),
            topRight: CGPoint(x: frame.minX + tr.x * scaleX, y: frame.minY + tr.y * scaleY),
            bottomRight: CGPoint(x: frame.minX + br.x * scaleX, y: frame.minY + br.y * scaleY),
            bottomLeft: CGPoint(x: frame.minX + bl.x * scaleX, y: frame.minY + bl.y * scaleY)
        )
    }

    private func getImageFrame() -> CGRect? {
        // Helper to get the current imageFrame (used in main thread)
        if imageFrame.width > 0 && imageFrame.height > 0 {
            return imageFrame
        }
        return nil
    }

    private func resetQuadToRectangle() {
        if let frame = getImageFrame() {
            let cropWidth = frame.width * 0.8
            let cropHeight = frame.height * 0.8
            let cropX = frame.minX + (frame.width - cropWidth) / 2
            let cropY = frame.minY + (frame.height - cropHeight) / 2
            quad = Quadrilateral(
                topLeft: CGPoint(x: cropX, y: cropY),
                topRight: CGPoint(x: cropX + cropWidth, y: cropY),
                bottomRight: CGPoint(x: cropX + cropWidth, y: cropY + cropHeight),
                bottomLeft: CGPoint(x: cropX, y: cropY + cropHeight)
            )
        }
    }
}

// Preference key to get the image frame
struct ImageFramePreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

struct QuadCropOverlayView: View {
    @Binding var quad: Quadrilateral
    let imageFrame: CGRect
    let cornerSize: CGFloat
    @State private var activeCorner: Int? = nil
    
    var body: some View {
        ZStack {
            // Mask outside quad
            Path { path in
                path.addRect(CGRect(origin: .zero, size: CGSize(width: imageFrame.width, height: imageFrame.height)))
                path.move(to: quad.topLeft)
                path.addLine(to: quad.topRight)
                path.addLine(to: quad.bottomRight)
                path.addLine(to: quad.bottomLeft)
                path.closeSubpath()
            }
            .fill(Color.black.opacity(0.5), style: FillStyle(eoFill: true))
            
            // Draw quad border
            Path { path in
                path.move(to: quad.topLeft)
                path.addLine(to: quad.topRight)
                path.addLine(to: quad.bottomRight)
                path.addLine(to: quad.bottomLeft)
                path.closeSubpath()
            }
            .stroke(Color.white, lineWidth: 2)
            
            // Corner controls
            ForEach(0..<4, id: \.self) { i in
                let point = [quad.topLeft, quad.topRight, quad.bottomRight, quad.bottomLeft][i]
                Circle()
                    .fill(Color.white)
                    .frame(width: cornerSize / 2, height: cornerSize / 2)
                    .overlay(Circle().stroke(Color.blue, lineWidth: 2))
                    .position(point)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                activeCorner = i
                                updateCorner(index: i, to: value.location)
                            }
                            .onEnded { _ in
                                activeCorner = nil
                            }
                    )
            }
        }
    }
    
    private func updateCorner(index: Int, to location: CGPoint) {
        switch index {
        case 0: quad.topLeft = clamp(location)
        case 1: quad.topRight = clamp(location)
        case 2: quad.bottomRight = clamp(location)
        case 3: quad.bottomLeft = clamp(location)
        default: break
        }
    }
    
    private func clamp(_ point: CGPoint) -> CGPoint {
        CGPoint(
            x: min(max(point.x, imageFrame.minX), imageFrame.maxX),
            y: min(max(point.y, imageFrame.minY), imageFrame.maxY)
        )
    }
}
