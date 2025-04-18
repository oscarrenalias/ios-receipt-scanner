//
//  ImageEditorView.swift
//  ReceiptScanner
//
//  Created by oscar.renalias on 18.4.2025.
//


import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

struct ImageEditorView: View {
    let image: UIImage
    
    @State private var processedImage: UIImage?
    @State private var brightness: Double = 0.0
    @State private var contrast: Double = 1.0
    @State private var sharpness: Double = 0.0
    @State private var isBlackAndWhite: Bool = false
    @State private var showingCropView = false
    @State private var showingSaveOptions = false
    @State private var croppedImage: UIImage?
    
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack {
            ScrollView {
                VStack(spacing: 20) {
                    Image(uiImage: processedImage ?? image)
                        .resizable()
                        .scaledToFit()
                        .cornerRadius(8)
                        .padding()
                    
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
                    }
                    .padding()
                }
            }
            
            Button(action: {
                showingSaveOptions = true
            }) {
                Text("Save Receipt")
                    .fontWeight(.semibold)
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .padding()
            }
        }
        .navigationTitle("Edit Receipt")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            processedImage = image
        }
        .sheet(isPresented: $showingCropView) {
            let img = processedImage ?? image
            ImageCropView(image: img) { croppedImg in
                if let croppedImg = croppedImg {
                    self.processedImage = croppedImg
                    updateImage()
                }
            }
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
                    .default(Text("Process with OCR")) {
                        performOCR()
                    },
                    .cancel()
                ]
            )
        }
    }
    
    func updateImage() {
        let inputImage = processedImage ?? image
        guard let ciImage = CIImage(image: inputImage) else { return }
        
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
            processedImage = UIImage(cgImage: cgImage)
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
        // In a real app, you would integrate with Vision framework for OCR
        // For this example, we'll just show a placeholder message
        let alert = UIAlertController(title: "OCR Processing", message: "Text recognition would be performed here using Vision framework", preferredStyle: .alert)
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

struct ImageEditorView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ImageEditorView(image: UIImage(systemName: "doc.text.viewfinder") ?? UIImage())
        }
    }
}
