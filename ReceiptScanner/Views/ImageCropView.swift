//
//  ImageCropView.swift
//  ReceiptScanner
//
//  Created by oscar.renalias on 18.4.2025.
//


import SwiftUI

struct ImageCropView: View {
    let image: UIImage
    let onCrop: (UIImage?) -> Void
    
    @State private var cropRect: CGRect = .zero
    @State private var startLocation: CGPoint = .zero
    @State private var isDragging = false
    @State private var cornerDragging: Corner? = nil
    @Environment(\.presentationMode) var presentationMode
    
    enum Corner {
        case topLeft, topRight, bottomLeft, bottomRight
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .onAppear {
                        let imageSize = image.size
                        let screenSize = geometry.size
                        
                        let scale = min(screenSize.width / imageSize.width, screenSize.height / imageSize.height)
                        let scaledWidth = imageSize.width * scale
                        let scaledHeight = imageSize.height * scale
                        
                        let x = (screenSize.width - scaledWidth) / 2
                        let y = (screenSize.height - scaledHeight) / 2
                        
                        // Initialize crop rect to 80% of the image size
                        let cropWidth = scaledWidth * 0.8
                        let cropHeight = scaledHeight * 0.8
                        let cropX = x + (scaledWidth - cropWidth) / 2
                        let cropY = y + (scaledHeight - cropHeight) / 2
                        
                        cropRect = CGRect(x: cropX, y: cropY, width: cropWidth, height: cropHeight)
                    }
                
                // Crop rectangle
                Path { path in
                    path.addRect(cropRect)
                }
                .stroke(Color.white, lineWidth: 2)
                
                // Corner handles
                ForEach(0..<4) { index in
                    let corner = [Corner.topLeft, .topRight, .bottomLeft, .bottomRight][index]
                    let position = cornerPosition(for: corner)
                    
                    Circle()
                        .fill(Color.white)
                        .frame(width: 20, height: 20)
                        .position(position)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    if cornerDragging == nil {
                                        cornerDragging = corner
                                    }
                                    
                                    if cornerDragging == corner {
                                        updateCropRect(for: corner, with: value.location)
                                    }
                                }
                                .onEnded { _ in
                                    cornerDragging = nil
                                }
                        )
                }
            }
        }
        .navigationBarTitle("Crop Image", displayMode: .inline)
        .navigationBarItems(
            leading: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            },
            trailing: Button("Done") {
                cropImage()
                presentationMode.wrappedValue.dismiss()
            }
        )
    }
    
    func cornerPosition(for corner: Corner) -> CGPoint {
        switch corner {
        case .topLeft:
            return CGPoint(x: cropRect.minX, y: cropRect.minY)
        case .topRight:
            return CGPoint(x: cropRect.maxX, y: cropRect.minY)
        case .bottomLeft:
            return CGPoint(x: cropRect.minX, y: cropRect.maxY)
        case .bottomRight:
            return CGPoint(x: cropRect.maxX, y: cropRect.maxY)
        }
    }
    
    func updateCropRect(for corner: Corner, with point: CGPoint) {
        var newRect = cropRect
        
        switch corner {
        case .topLeft:
            newRect = CGRect(
                x: min(point.x, cropRect.maxX - 50),
                y: min(point.y, cropRect.maxY - 50),
                width: cropRect.maxX - min(point.x, cropRect.maxX - 50),
                height: cropRect.maxY - min(point.y, cropRect.maxY - 50)
            )
        case .topRight:
            newRect = CGRect(
                x: cropRect.minX,
                y: min(point.y, cropRect.maxY - 50),
                width: max(point.x - cropRect.minX, 50),
                height: cropRect.maxY - min(point.y, cropRect.maxY - 50)
            )
        case .bottomLeft:
            newRect = CGRect(
                x: min(point.x, cropRect.maxX - 50),
                y: cropRect.minY,
                width: cropRect.maxX - min(point.x, cropRect.maxX - 50),
                height: max(point.y - cropRect.minY, 50)
            )
        case .bottomRight:
            newRect = CGRect(
                x: cropRect.minX,
                y: cropRect.minY,
                width: max(point.x - cropRect.minX, 50),
                height: max(point.y - cropRect.minY, 50)
            )
        }
        
        cropRect = newRect
    }
    
    func cropImage() {
        // Convert crop rect to image coordinates
        let imageSize = image.size
        let viewSize = UIScreen.main.bounds.size
        
        let scale = min(viewSize.width / imageSize.width, viewSize.height / imageSize.height)
        let scaledWidth = imageSize.width * scale
        let scaledHeight = imageSize.height * scale
        
        let x = (viewSize.width - scaledWidth) / 2
        let y = (viewSize.height - scaledHeight) / 2
        
        // Convert crop rect from view coordinates to image coordinates
        let cropX = (cropRect.minX - x) / scale
        let cropY = (cropRect.minY - y) / scale
        let cropWidth = cropRect.width / scale
        let cropHeight = cropRect.height / scale
        
        let imageCropRect = CGRect(x: cropX, y: cropY, width: cropWidth, height: cropHeight)
        
        // Perform the crop
        if let cgImage = image.cgImage?.cropping(to: imageCropRect) {
            let croppedImage = UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
            onCrop(croppedImage)
        } else {
            onCrop(nil)
        }
    }
}

struct ImageCropView_Previews: PreviewProvider {
    static var previews: some View {
        ImageCropView(image: UIImage(systemName: "doc.text.viewfinder") ?? UIImage()) { _ in }
    }
}
