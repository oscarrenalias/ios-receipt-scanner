import SwiftUI
import UIKit

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
            }
            //.ignoresSafeArea() // Ensure the crop view takes up the full screen
        }
        .navigationBarHidden(true)
        .statusBar(hidden: true)
        .background(Color.black) // Ensure full black background
    }
    
    private func performCrop() {
        print("🔍 Performing crop with rect: \(cropRect)")
        
        // Convert crop rect from display coordinates to image coordinates
        let imageDisplayFrame = imageFrame
        
        // Calculate the scale between the displayed image and the actual image
        let scaleX = image.size.width / imageDisplayFrame.width
        let scaleY = image.size.height / imageDisplayFrame.height
        
        // Calculate the crop rect in the image's coordinate space
        let cropX = (cropRect.minX - imageDisplayFrame.minX) * scaleX
        let cropY = (cropRect.minY - imageDisplayFrame.minY) * scaleY
        let cropWidth = cropRect.width * scaleX
        let cropHeight = cropRect.height * scaleY
        
        let imageCropRect = CGRect(x: cropX, y: cropY, width: cropWidth, height: cropHeight)
        
        print("🔍 Image crop rect: \(imageCropRect)")
        print("🔍 Original image size: \(image.size.width) x \(image.size.height)")
        
        // Ensure crop rect is within image bounds
        let validCropRect = CGRect(
            x: max(0, min(imageCropRect.minX, image.size.width - 1)),
            y: max(0, min(imageCropRect.minY, image.size.height - 1)),
            width: min(imageCropRect.width, image.size.width - imageCropRect.minX),
            height: min(imageCropRect.height, image.size.height - imageCropRect.minY)
        )
        
        print("🔍 Valid crop rect: \(validCropRect)")
        
        // Perform the actual cropping
        if let cgImage = image.cgImage?.cropping(to: validCropRect) {
            let croppedImage = UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
            
            print("🔍 Cropping successful, new image size: \(croppedImage.size.width) x \(croppedImage.size.height)")
            
            // Return the cropped image
            presentationMode.wrappedValue.dismiss()
            completion(croppedImage, validCropRect)
        } else {
            // Cropping failed
            print("❌ Cropping failed")
            presentationMode.wrappedValue.dismiss()
            completion(nil, nil)
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
