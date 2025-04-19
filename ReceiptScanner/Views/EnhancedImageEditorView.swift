import SwiftUI
import SDWebImageSwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins
import Vision
import UIKit

struct EnhancedImageEditorView: View {
    let image: UIImage
    
    @State private var processedImage: UIImage?
    @State private var brightness: Double = 0.0
    @State private var contrast: Double = 1.0
    @State private var sharpness: Double = 0.0
    @State private var isBlackAndWhite: Bool = false
    @State private var showingCropView = false
    @State private var showingSaveOptions = false
    @State private var showingOCRResults = false
    @State private var ocrText: String = ""
    @State private var isProcessing = false
    @State private var imageURL: URL?
    @State private var zoomScale: CGFloat = 1.0
    
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.colorScheme) private var colorScheme
    
    private func cacheAndDisplayImage() {
        if let processedImage = processedImage {
            // Create a temporary URL for the image
            let temporaryDirectoryURL = FileManager.default.temporaryDirectory
            let fileName = UUID().uuidString + ".jpg"
            let fileURL = temporaryDirectoryURL.appendingPathComponent(fileName)
            
            // Save the image to the temporary URL
            if let imageData = processedImage.jpegData(compressionQuality: 0.9) {
                try? imageData.write(to: fileURL)
                
                // Update the UI on the main thread
                DispatchQueue.main.async {
                    self.imageURL = fileURL
                    print("🔍 Image cached at: \(fileURL.path)")
                }
            }
        }
    }
    
    private func updateImage() {
        isProcessing = true
        
        // Delay the processing slightly to avoid rapid consecutive updates
        // when the user is dragging a slider
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            DispatchQueue.global(qos: .userInitiated).async {
                guard let ciImage = CIImage(image: processedImage ?? image) else {
                    DispatchQueue.main.async {
                        isProcessing = false
                    }
                    return
                }
            
                let context = CIContext()
                
                // Apply brightness adjustment
                var currentImage = ciImage
                if brightness != 0 {
                    let brightnessFilter = CIFilter.colorControls()
                    brightnessFilter.inputImage = currentImage
                    brightnessFilter.brightness = Float(brightness)
                    if let outputImage = brightnessFilter.outputImage {
                        currentImage = outputImage
                    }
                }
                
                // Apply contrast adjustment
                if contrast != 1.0 {
                    let contrastFilter = CIFilter.colorControls()
                    contrastFilter.inputImage = currentImage
                    contrastFilter.contrast = Float(contrast)
                    if let outputImage = contrastFilter.outputImage {
                        currentImage = outputImage
                    }
                }
                
                // Apply sharpness adjustment
                if sharpness != 0 {
                    let sharpenFilter = CIFilter.sharpenLuminance()
                    sharpenFilter.inputImage = currentImage
                    sharpenFilter.sharpness = Float(sharpness * 2) // Scale for better control
                    if let outputImage = sharpenFilter.outputImage {
                        currentImage = outputImage
                    }
                }
                
                // Apply black and white filter if selected
                if isBlackAndWhite {
                    let monoFilter = CIFilter.photoEffectMono()
                    monoFilter.inputImage = currentImage
                    if let outputImage = monoFilter.outputImage {
                        currentImage = outputImage
                    }
                }
                
                // Convert back to UIImage
                if let cgImage = context.createCGImage(currentImage, from: currentImage.extent) {
                    let processedUIImage = UIImage(cgImage: cgImage)
                    
                    DispatchQueue.main.async {
                        self.processedImage = processedUIImage
                        self.cacheAndDisplayImage()
                        self.isProcessing = false
                    }
                } else {
                    DispatchQueue.main.async {
                        self.isProcessing = false
                    }
                }
            }
        }
    }
    
    private func resetImage() {
        processedImage = image
        brightness = 0.0
        contrast = 1.0
        sharpness = 0.0
        isBlackAndWhite = false
        cacheAndDisplayImage()
    }
    
    private func performOCR() {
        isProcessing = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            guard let cgImage = (processedImage ?? image).cgImage else {
                DispatchQueue.main.async {
                    self.isProcessing = false
                }
                return
            }
            
            // Create a new image request handler
            let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            // Create a new request to recognize text
            let request = VNRecognizeTextRequest { request, error in
                guard error == nil else {
                    print("OCR Error: \(error!.localizedDescription)")
                    DispatchQueue.main.async {
                        self.isProcessing = false
                    }
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    DispatchQueue.main.async {
                        self.isProcessing = false
                    }
                    return
                }
                
                // Process the recognized text
                let recognizedText = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }.joined(separator: "\n")
                
                DispatchQueue.main.async {
                    self.ocrText = recognizedText
                    self.isProcessing = false
                    self.showingOCRResults = true
                }
            }
            
            // Configure the recognition level
            request.recognitionLevel = .accurate
            
            do {
                try requestHandler.perform([request])
            } catch {
                print("OCR Request Error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.isProcessing = false
                }
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack(alignment: .bottom) {
                Color.black.edgesIgnoringSafeArea(.all)
                
                // Main content with zoomable image
                ZoomableScrollView(
                    minScale: 1.0,
                    maxScale: 5.0,
                    currentScale: $zoomScale
                ) {
                    VStack {
                        if let imageURL = imageURL, !isProcessing {
                            WebImage(url: imageURL)
                                .resizable()
                                .scaledToFit()
                                .padding(.top, 20) // Add padding at the top
                                .padding(.horizontal)
                        } else if let processedImage = processedImage, !isProcessing {
                            Image(uiImage: processedImage)
                                .resizable()
                                .scaledToFit()
                                .padding(.top, 20) // Add padding at the top
                                .padding(.horizontal)
                        } else if !isProcessing {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .padding(.top, 20) // Add padding at the top
                                .padding(.horizontal)
                        }
                        
                        // Add extra space at the bottom to ensure the image is visible above controls
                        Spacer(minLength: 350)
                    }
                }
                
                // Full screen overlay for processing indicator
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
                
                // Controls section
                VStack(spacing: 0) {
                    // Sliders and controls section
                    if !isProcessing {
                        VStack(spacing: 15) {
                            // Brightness slider
                            VStack(alignment: .leading) {
                                Text("Brightness: \(String(format: "%.2f", brightness))")
                                    .foregroundColor(.white)
                                
                                Slider(value: $brightness, in: -1...1, step: 0.05)
                                    .accentColor(.blue)
                                    .onChange(of: brightness) { _ in
                                        // Only update if not already processing
                                        if !isProcessing {
                                            updateImage()
                                        }
                                    }
                            }
                            .padding(.horizontal)
                            
                            // Contrast slider
                            VStack(alignment: .leading) {
                                Text("Contrast: \(String(format: "%.2f", contrast))")
                                    .foregroundColor(.white)
                                
                                Slider(value: $contrast, in: 0.5...1.5, step: 0.05)
                                    .accentColor(.blue)
                                    .onChange(of: contrast) { _ in
                                        // Only update if not already processing
                                        if !isProcessing {
                                            updateImage()
                                        }
                                    }
                            }
                            .padding(.horizontal)
                            
                            // Sharpness slider
                            VStack(alignment: .leading) {
                                Text("Sharpness: \(String(format: "%.2f", sharpness))")
                                    .foregroundColor(.white)
                                
                                Slider(value: $sharpness, in: 0...1, step: 0.05)
                                    .accentColor(.blue)
                                    .onChange(of: sharpness) { _ in
                                        // Only update if not already processing
                                        if !isProcessing {
                                            updateImage()
                                        }
                                    }
                            }
                            .padding(.horizontal)
                            
                            // Black and white toggle
                            Toggle(isOn: $isBlackAndWhite.animation()) {
                                Text("Black & White")
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal)
                            .onChange(of: isBlackAndWhite) { _ in
                                // Only update if not already processing
                                if !isProcessing {
                                    updateImage()
                                }
                            }
                        }
                        .padding(.vertical)
                        .background(Color.black.opacity(0.8))
                    }
                    
                    Divider()
                    
                    // Action buttons - styled like the tab bar in ScannerView
                    HStack(spacing: 0) {
                        // Crop button
                        Button(action: {
                            showingCropView = true
                        }) {
                            VStack(spacing: 4) {
                                Image(systemName: "crop")
                                    .font(.system(size: 24))
                                Text("Crop")
                                    .font(.caption)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                        }
                        .foregroundColor(.blue)
                        
                        // Reset button
                        Button(action: {
                            resetImage()
                        }) {
                            VStack(spacing: 4) {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.system(size: 24))
                                Text("Reset")
                                    .font(.caption)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                        }
                        .foregroundColor(.blue)
                        
                        // OCR button
                        Button(action: {
                            performOCR()
                        }) {
                            VStack(spacing: 4) {
                                Image(systemName: "text.viewfinder")
                                    .font(.system(size: 24))
                                Text("OCR")
                                    .font(.caption)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                        }
                        .foregroundColor(.blue)
                        
                        // Save button
                        Button(action: {
                            showingSaveOptions = true
                        }) {
                            VStack(spacing: 4) {
                                Image(systemName: "square.and.arrow.down")
                                    .font(.system(size: 24))
                                Text("Save")
                                    .font(.caption)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                        }
                        .foregroundColor(.blue)
                    }
                    .background(
                        colorScheme == .dark ? 
                            Color(UIColor.systemBackground).opacity(0.9) : 
                            Color(UIColor.systemBackground).opacity(0.95)
                    )
                    .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: -5)
                }
                .edgesIgnoringSafeArea(.bottom)
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(leading: 
                Button(action: {
                    print("🔍 Close button tapped, dismissing editor")
                    // Simple dismissal without clearing images
                    withAnimation(.easeOut(duration: 0.2)) {
                        presentationMode.wrappedValue.dismiss()
                    }
                }) {
                    Image(systemName: "xmark")
                        .foregroundColor(.white)
                        .font(.system(size: 16, weight: .bold))
                        .padding(8)
                        .background(Color.gray.opacity(0.6))
                        .clipShape(Circle())
                }
            )
            .onAppear {
                print("🔍 EnhancedImageEditorView appeared")
                processedImage = image
                cacheAndDisplayImage()
            }
            .sheet(isPresented: $showingCropView) {
                let img = processedImage ?? image
                ImageCropView(image: img) { croppedImg in
                    if let croppedImg = croppedImg {
                        print("🔍 Received cropped image with dimensions: \(croppedImg.size.width) x \(croppedImg.size.height)")
                        self.processedImage = croppedImg
                        cacheAndDisplayImage()
                        updateImage()
                    } else {
                        print("🔍 Crop operation cancelled or failed")
                    }
                }
            }
            .sheet(isPresented: $showingOCRResults) {
                OCRResultView(text: ocrText)
            }
            .actionSheet(isPresented: $showingSaveOptions) {
                ActionSheet(
                    title: Text("Save Options"),
                    message: Text("Choose where to save the processed receipt"),
                    buttons: [
                        .default(Text("Save to Photos")) {
                            if let image = processedImage {
                                UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                            }
                        },
                        .cancel()
                    ]
                )
            }
        }
    }
}

// Extension to apply corner radius to specific corners
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

struct OCRResultView: View {
    let text: String
    @Environment(\.presentationMode) var presentationMode
    @State private var showingShareSheet = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading) {
                    Text(text.isEmpty ? "No text detected" : text)
                        .padding()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("OCR Results")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("Close") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button(action: {
                    showingShareSheet = true
                }) {
                    Image(systemName: "square.and.arrow.up")
                }
            )
            .sheet(isPresented: $showingShareSheet) {
                ShareSheet(items: [text])
            }
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
