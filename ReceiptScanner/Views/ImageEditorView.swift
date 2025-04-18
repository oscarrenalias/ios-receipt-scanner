import SwiftUI
import UIKit

struct ImageEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var editedImage: UIImage
    @State private var isShowingCropUI = false
    @State private var brightness: Double = 0
    @State private var contrast: Double = 1
    @State private var isBlackAndWhite = false
    @State private var isProcessing = false
    
    // For keeping track of the original image
    private let originalImage: UIImage
    
    // Callback for when editing is complete
    var onImageEdited: (UIImage) -> Void
    
    init(image: UIImage, onImageEdited: @escaping (UIImage) -> Void) {
        self._editedImage = State(initialValue: image)
        self.originalImage = image
        self.onImageEdited = onImageEdited
    }
    
    var body: some View {
        ZStack {
            // Black background
            Color.black.edgesIgnoringSafeArea(.all)
            
            // Image display
            GeometryReader { geometry in
                Image(uiImage: editedImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: geometry.size.width, height: geometry.size.height)
            }
            
            // Top toolbar with close button
            VStack {
                HStack {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                            .padding()
                            .background(Circle().fill(Color.black.opacity(0.5)))
                    }
                    .padding(.leading, 16)
                    
                    Spacer()
                    
                    Button(action: {
                        saveEdits()
                    }) {
                        Text("Done")
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding()
                            .background(Capsule().fill(Color.blue))
                    }
                    .padding(.trailing, 16)
                }
                .padding(.top, 8)
                
                Spacer()
                
                // Bottom toolbar
                VStack(spacing: 20) {
                    // Editing controls
                    if !isShowingCropUI {
                        // Brightness slider
                        VStack(alignment: .leading) {
                            HStack {
                                Image(systemName: "sun.min")
                                    .foregroundColor(.white)
                                Text("Brightness")
                                    .foregroundColor(.white)
                                Spacer()
                            }
                            
                            Slider(value: $brightness, in: -1...1, step: 0.05)
                                .accentColor(.white)
                                .onChange(of: brightness) { _ in
                                    applyFilters()
                                }
                        }
                        .padding(.horizontal)
                        
                        // Contrast slider
                        VStack(alignment: .leading) {
                            HStack {
                                Image(systemName: "circle.lefthalf.filled")
                                    .foregroundColor(.white)
                                Text("Contrast")
                                    .foregroundColor(.white)
                                Spacer()
                            }
                            
                            Slider(value: $contrast, in: 0.5...1.5, step: 0.05)
                                .accentColor(.white)
                                .onChange(of: contrast) { _ in
                                    applyFilters()
                                }
                        }
                        .padding(.horizontal)
                        
                        // Black & White toggle
                        Toggle(isOn: $isBlackAndWhite) {
                            HStack {
                                Image(systemName: "camera.filters")
                                    .foregroundColor(.white)
                                Text("Black & White")
                                    .foregroundColor(.white)
                            }
                        }
                        .toggleStyle(SwitchToggleStyle(tint: .blue))
                        .padding(.horizontal)
                        .onChange(of: isBlackAndWhite) { _ in
                            applyFilters()
                        }
                    }
                    
                    // Bottom action buttons
                    HStack(spacing: 30) {
                        Button(action: {
                            isShowingCropUI.toggle()
                        }) {
                            VStack {
                                Image(systemName: isShowingCropUI ? "checkmark" : "crop")
                                    .font(.system(size: 24))
                                    .foregroundColor(.white)
                                Text(isShowingCropUI ? "Done" : "Crop")
                                    .font(.caption)
                                    .foregroundColor(.white)
                            }
                        }
                        
                        Button(action: {
                            resetImage()
                        }) {
                            VStack {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.system(size: 24))
                                    .foregroundColor(.white)
                                Text("Reset")
                                    .font(.caption)
                                    .foregroundColor(.white)
                            }
                        }
                        
                        Button(action: {
                            performOCR()
                        }) {
                            VStack {
                                Image(systemName: "text.viewfinder")
                                    .font(.system(size: 24))
                                    .foregroundColor(.white)
                                Text("OCR")
                                    .font(.caption)
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    .padding(.vertical)
                }
                .padding(.bottom, 20)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.black.opacity(0), Color.black.opacity(0.8)]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
            
            // Processing overlay
            if isProcessing {
                ZStack {
                    Color.black.opacity(0.7)
                    VStack {
                        ProgressView()
                            .scaleEffect(1.5)
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        Text("Processing...")
                            .foregroundColor(.white)
                            .padding(.top)
                    }
                }
                .edgesIgnoringSafeArea(.all)
            }
        }
        .statusBar(hidden: true)
        .edgesIgnoringSafeArea(.all)
    }
    
    // Apply image filters based on current settings
    private func applyFilters() {
        guard let ciImage = CIImage(image: originalImage) else { return }
        
        var currentCIImage = ciImage
        
        // Apply brightness
        if brightness != 0 {
            let brightnessFilter = CIFilter(name: "CIColorControls")
            brightnessFilter?.setValue(currentCIImage, forKey: kCIInputImageKey)
            brightnessFilter?.setValue(brightness, forKey: kCIInputBrightnessKey)
            if let outputImage = brightnessFilter?.outputImage {
                currentCIImage = outputImage
            }
        }
        
        // Apply contrast
        if contrast != 1 {
            let contrastFilter = CIFilter(name: "CIColorControls")
            contrastFilter?.setValue(currentCIImage, forKey: kCIInputImageKey)
            contrastFilter?.setValue(contrast, forKey: kCIInputContrastKey)
            if let outputImage = contrastFilter?.outputImage {
                currentCIImage = outputImage
            }
        }
        
        // Apply black and white filter if enabled
        if isBlackAndWhite {
            let monoFilter = CIFilter(name: "CIPhotoEffectMono")
            monoFilter?.setValue(currentCIImage, forKey: kCIInputImageKey)
            if let outputImage = monoFilter?.outputImage {
                currentCIImage = outputImage
            }
        }
        
        // Convert back to UIImage
        let context = CIContext()
        if let cgImage = context.createCGImage(currentCIImage, from: currentCIImage.extent) {
            editedImage = UIImage(cgImage: cgImage)
        }
    }
    
    // Reset to original image
    private func resetImage() {
        editedImage = originalImage
        brightness = 0
        contrast = 1
        isBlackAndWhite = false
    }
    
    // Save edits and dismiss
    private func saveEdits() {
        onImageEdited(editedImage)
        dismiss()
    }
    
    // Perform OCR on the image
    private func performOCR() {
        isProcessing = true
        
        // Here you would implement OCR functionality
        // For now, we'll just simulate processing
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            isProcessing = false
            // In a real implementation, you would process the OCR results here
        }
    }
}

// Preview
struct ImageEditorView_Previews: PreviewProvider {
    static var previews: some View {
        ImageEditorView(image: UIImage(systemName: "doc")!) { _ in }
    }
}
