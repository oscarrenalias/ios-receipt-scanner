//
//  EnhancedImageEditorView.swift
//  ReceiptScanner
//
//  Created by oscar.renalias on 18.4.2025.
//


import SwiftUI
import SDWebImageSwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

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
    
    var body: some View {
        VStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Enhanced image display with SDWebImage
                    if let imageURL = imageURL {
                        WebImage(url: imageURL)
                            .resizable()
                            .indicator { _, _ in
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                            }
                            .transition(AnyTransition.opacity.animation(.easeInOut(duration: 0.5)))
                            .scaledToFit()
                            .cornerRadius(8)
                            .padding()
                    } else {
                        Image(uiImage: processedImage ?? image)
                            .resizable()
                            .scaledToFit()
                            .cornerRadius(8)
                            .padding()
                    }
                    
                    if isProcessing {
                        ProgressView("Processing image...")
                            .progressViewStyle(CircularProgressViewStyle())
                            .padding()
                    } else {
                        VStack(spacing: 15) {
                            Button(action: {
                                showingCropView = true
                            }) {
                                HStack {
                                    Image(systemName: "crop")
                                    Text("Crop Image")
                                }
                                .frame(minWidth: 0, maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                            }
                            
                            VStack(alignment: .leading) {
                                Text("Brightness: \(Int(brightness * 100))%")
                                Slider(value: $brightness, in: -0.5...0.5, step: 0.01)
                                    .onChange(of: brightness) { _ in
                                        updateImage()
                                    }
                            }
                            
                            VStack(alignment: .leading) {
                                Text("Contrast: \(Int(contrast * 100))%")
                                Slider(value: $contrast, in: 0.5...1.5, step: 0.01)
                                    .onChange(of: contrast) { _ in
                                        updateImage()
                                    }
                            }
                            
                            VStack(alignment: .leading) {
                                Text("Sharpness: \(Int(sharpness * 100))%")
                                Slider(value: $sharpness, in: 0...1, step: 0.01)
                                    .onChange(of: sharpness) { _ in
                                        updateImage()
                                    }
                            }
                            
                            Toggle(isOn: $isBlackAndWhite) {
                                Text("Black & White")
                            }
                            .onChange(of: isBlackAndWhite) { _ in
                                updateImage()
                            }
                            .padding(.vertical)
                            
                            Button(action: {
                                optimizeForOCR()
                            }) {
                                HStack {
                                    Image(systemName: "text.viewfinder")
                                    Text("Optimize for OCR")
                                }
                                .frame(minWidth: 0, maxWidth: .infinity)
                                .padding()
                                .background(Color.purple)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                            }
                        }
                        .padding()
                    }
                }
            }
            
            HStack(spacing: 20) {
                Button(action: {
                    performOCR()
                }) {
                    HStack {
                        Image(systemName: "doc.text.magnifyingglass")
                        Text("Scan Text")
                    }
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .padding()
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                
                Button(action: {
                    showingSaveOptions = true
                }) {
                    HStack {
                        Image(systemName: "square.and.arrow.down")
                        Text("Save")
                    }
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
            }
            .padding()
        }
        .navigationTitle("Edit Receipt")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            processedImage = image
            cacheAndDisplayImage()
        }
        .sheet(isPresented: $showingCropView) {
            let img = processedImage ?? image
            ImageCropView(image: img) { croppedImg in
                if let croppedImg = croppedImg {
                    self.processedImage = croppedImg
                    cacheAndDisplayImage()
                    updateImage()
                }
            }
        }
        .sheet(isPresented: $showingOCRResults) {
            OCRResultView(text: ocrText)
        }
        .actionSheet(isPresented: $showingSaveOptions) {
            ActionSheet(
                title: Text("Save Options"),
                message: Text("Choose where to save your receipt"),
                buttons: [
                    .default(Text("Save to Photos")) {
                        saveToPhotos()
                    },
                    .default(Text("Save to Files")) {
                        // This would typically use UIDocumentPickerViewController
                        // For simplicity, we'll just save to photos in this example
                        saveToPhotos()
                    },
                    .cancel()
                ]
            )
        }
    }
    
    private func cacheAndDisplayImage() {
        guard let image = processedImage else { return }
        
        // Generate a unique key for this image
        let key = UUID().uuidString
        
        // Cache the image and get a URL for it
        if let url = ImageProcessingService.shared.cacheImage(image, withKey: key) {
            self.imageURL = url
        }
    }
    
    func updateImage() {
        isProcessing = true
        
        // Process image in background
        DispatchQueue.global(qos: .userInitiated).async {
            let inputImage = processedImage ?? image
            guard let ciImage = CIImage(image: inputImage) else {
                DispatchQueue.main.async {
                    isProcessing = false
                }
                return
            }
            
            let context = CIContext()
            var currentCIImage = ciImage
            
            // Apply brightness and contrast
            let brightnessFilter = CIFilter.colorControls()
            brightnessFilter.inputImage = currentCIImage
            brightnessFilter.brightness = Float(brightness)
            brightnessFilter.contrast = Float(contrast)
            
            if let outputImage = brightnessFilter.outputImage {
                currentCIImage = outputImage
            }
            
            // Apply sharpness
            if sharpness > 0 {
                let sharpenFilter = CIFilter.sharpenLuminance()
                sharpenFilter.inputImage = currentCIImage
                sharpenFilter.sharpness = Float(sharpness * 2)
                
                if let outputImage = sharpenFilter.outputImage {
                    currentCIImage = outputImage
                }
            }
            
            // Apply black and white filter if selected
            if isBlackAndWhite {
                let monoFilter = CIFilter.photoEffectMono()
                monoFilter.inputImage = currentCIImage
                
                if let outputImage = monoFilter.outputImage {
                    currentCIImage = outputImage
                }
            }
            
            // Convert back to UIImage
            if let cgImage = context.createCGImage(currentCIImage, from: currentCIImage.extent) {
                let newImage = UIImage(cgImage: cgImage)
                
                // Update UI on main thread
                DispatchQueue.main.async {
                    processedImage = newImage
                    cacheAndDisplayImage()
                    isProcessing = false
                }
            } else {
                DispatchQueue.main.async {
                    isProcessing = false
                }
            }
        }
    }
    
    func optimizeForOCR() {
        isProcessing = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            let inputImage = processedImage ?? image
            
            // Use the SDWebImage service for OCR optimization
            let optimizedImage = ImageProcessingService.shared.optimizeForOCR(inputImage)
            
            DispatchQueue.main.async {
                processedImage = optimizedImage
                cacheAndDisplayImage()
                isProcessing = false
                
                // Set black and white to true since OCR optimization includes this
                isBlackAndWhite = true
                
                // Adjust other parameters for optimal OCR
                contrast = 1.3
                brightness = 0.1
                sharpness = 0.7
            }
        }
    }
    
    func saveToPhotos() {
        guard let image = processedImage else { return }
        
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        
        // Show a success message
        let alert = UIAlertController(title: "Saved", message: "Receipt saved to Photos", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        
        // Find the currently presented view controller
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            var currentController = rootViewController
            while let presentedController = currentController.presentedViewController {
                currentController = presentedController
            }
            currentController.present(alert, animated: true)
        }
    }
    
    func performOCR() {
        guard let image = processedImage else { return }
        
        isProcessing = true
        
        // Perform OCR in background
        DispatchQueue.global(qos: .userInitiated).async {
            OCRService.recognizeText(from: image) { recognizedText in
                DispatchQueue.main.async {
                    isProcessing = false
                    
                    if let text = recognizedText, !text.isEmpty {
                        self.ocrText = text
                        self.showingOCRResults = true
                    } else {
                        // Show error alert
                        let alert = UIAlertController(
                            title: "OCR Failed",
                            message: "Try adjusting the image or using 'Optimize for OCR' before scanning",
                            preferredStyle: .alert
                        )
                        alert.addAction(UIAlertAction(title: "OK", style: .default))
                        
                        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                           let rootViewController = windowScene.windows.first?.rootViewController {
                            var currentController = rootViewController
                            while let presentedController = currentController.presentedViewController {
                                currentController = presentedController
                            }
                            currentController.present(alert, animated: true)
                        }
                    }
                }
            }
        }
    }
}

struct OCRResultView: View {
    let text: String
    @Environment(\.presentationMode) var presentationMode
    @State private var shareText = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Recognized Text")
                        .font(.headline)
                    
                    Text(text)
                        .font(.body)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    
                    Button(action: {
                        shareText = true
                    }) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Share Text")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                }
                .padding()
            }
            .navigationBarTitle("OCR Results", displayMode: .inline)
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
            .sheet(isPresented: $shareText) {
                ActivityViewController(activityItems: [text])
            }
        }
    }
}

// Helper view to present UIActivityViewController
struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil
    
    func makeUIViewController(context: UIViewControllerRepresentableContext<ActivityViewController>) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: UIViewControllerRepresentableContext<ActivityViewController>) {}
}
