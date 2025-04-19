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
    
    @Environment(\.presentationMode) var presentationMode
    
    private func cacheAndDisplayImage() {
        if let processedImage = processedImage {
            // Create a temporary URL for the image
            let temporaryDirectoryURL = FileManager.default.temporaryDirectory
            let fileName = UUID().uuidString + ".jpg"
            let fileURL = temporaryDirectoryURL.appendingPathComponent(fileName)
            
            // Save the image to the temporary URL
            if let imageData = processedImage.jpegData(compressionQuality: 0.9) {
                try? imageData.write(to: fileURL)
                self.imageURL = fileURL
                print("🔍 Image cached at: \(fileURL.path)")
            }
        }
    }
    
    private func updateImage() {
        isProcessing = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            guard let ciImage = CIImage(image: processedImage ?? image) else {
                DispatchQueue.main.async {
                    isProcessing = false
                }
                return
            }
            
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
            
            // Apply sharpness
            if sharpness > 0 {
                let sharpenFilter = CIFilter(name: "CISharpenLuminance")
                sharpenFilter?.setValue(currentCIImage, forKey: kCIInputImageKey)
                sharpenFilter?.setValue(sharpness, forKey: kCIInputSharpnessKey)
                if let outputImage = sharpenFilter?.outputImage {
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
                let processedImage = UIImage(cgImage: cgImage)
                
                DispatchQueue.main.async {
                    self.processedImage = processedImage
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
            
            let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
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
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            VStack {
                if let imageURL = imageURL {
                    WebImage(url: imageURL)
                        .resizable()
                        .indicator(.activity)
                        .transition(.fade(duration: 0.5))
                        .scaledToFit()
                        .padding()
                } else if let processedImage = processedImage {
                    ZoomableImageView(image: processedImage)
                        .padding()
                } else {
                    ZoomableImageView(image: image)
                        .padding()
                }
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Brightness slider
                        VStack(alignment: .leading) {
                            Text("Brightness: \(String(format: "%.2f", brightness))")
                                .foregroundColor(.white)
                            
                            Slider(value: $brightness, in: -1...1, step: 0.05)
                                .accentColor(.blue)
                                .onChange(of: brightness) { _ in
                                    updateImage()
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
                                    updateImage()
                                }
                        }
                        .padding(.horizontal)
                        
                        // Sharpness slider
                        VStack(alignment: .leading) {
                            Text("Sharpness: \(String(format: "%.2f", sharpness))")
                                .foregroundColor(.white)
                            
                            Slider(value: $sharpness, in: 0...2, step: 0.05)
                                .accentColor(.blue)
                                .onChange(of: sharpness) { _ in
                                    updateImage()
                                }
                        }
                        .padding(.horizontal)
                        
                        // Black & White toggle
                        Toggle(isOn: $isBlackAndWhite) {
                            Text("Black & White")
                                .foregroundColor(.white)
                        }
                        .toggleStyle(SwitchToggleStyle(tint: .blue))
                        .padding(.horizontal)
                        .onChange(of: isBlackAndWhite) { _ in
                            updateImage()
                        }
                        
                        // Action buttons
                        HStack(spacing: 20) {
                            /*Button(action: {
                                print("🔍 Crop button tapped")
                                showingCropView = true
                            }) {
                                VStack {
                                    Image(systemName: "crop")
                                        .font(.system(size: 24))
                                    Text("Crop")
                                        .font(.caption)
                                }
                            }*/
                            
                            Button(action: {
                                resetImage()
                            }) {
                                VStack {
                                    Image(systemName: "arrow.counterclockwise")
                                        .font(.system(size: 24))
                                    Text("Reset")
                                        .font(.caption)
                                }
                            }
                            
                            /*Button(action: {
                                performOCR()
                            }) {
                                VStack {
                                    Image(systemName: "text.viewfinder")
                                        .font(.system(size: 24))
                                    Text("OCR")
                                        .font(.caption)
                                }
                            }*/
                            
                            Button(action: {
                                showingSaveOptions = true
                            }) {
                                VStack {
                                    Image(systemName: "square.and.arrow.down")
                                        .font(.system(size: 24))
                                    Text("Save")
                                        .font(.caption)
                                }
                            }
                        }
                        .foregroundColor(.white)
                        .padding()
                    }
                    .padding()
                }
            }
            .navigationTitle("Edit Receipt")
            .navigationBarTitleDisplayMode(.inline)
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
            
            if isProcessing {
                Color.black.opacity(0.7)
                    .edgesIgnoringSafeArea(.all)
                
                VStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                    
                    Text("Processing...")
                        .foregroundColor(.white)
                        .padding(.top)
                }
            }
        }
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
