import UIKit
import Vision
import CoreImage
import CoreImage.CIFilterBuiltins
// Import OpenCV wrapper

class ImageProcessingService {
    static let shared = ImageProcessingService()
    
    private let context = CIContext()
    private var imageCache = NSCache<NSString, UIImage>()
    
    private init() {}
    
    // MARK: - Image Enhancements
    
    func enhanceReceiptImage(_ image: UIImage) -> UIImage {
        // Use OpenCV for advanced document enhancement
        if let enhanced = OpenCVWrapper.enhanceDocument(image) {
            return enhanced
        }
        // Fallback to Core Image if OpenCV fails
        guard let ciImage = CIImage(image: image) else { return image }
        
        var currentCIImage = ciImage
        
        // Apply auto contrast
        let contrastFilter = CIFilter.colorControls()
        contrastFilter.inputImage = currentCIImage
        contrastFilter.contrast = 1.1 // Slightly increase contrast
        
        if let outputImage = contrastFilter.outputImage {
            currentCIImage = outputImage
        }
        
        // Apply slight sharpening
        let sharpenFilter = CIFilter.sharpenLuminance()
        sharpenFilter.inputImage = currentCIImage
        sharpenFilter.sharpness = 0.5
        
        if let outputImage = sharpenFilter.outputImage {
            currentCIImage = outputImage
        }
        
        // Convert back to UIImage
        guard let cgImage = context.createCGImage(currentCIImage, from: currentCIImage.extent) else {
            return image
        }
        
        return UIImage(cgImage: cgImage)
    }
    
    // MARK: - Image Adjustments
    
    func adjustBrightness(image: UIImage, value: Double) -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return nil }
        
        let filter = CIFilter.colorControls()
        filter.inputImage = ciImage
        filter.brightness = Float(value)
        
        guard let outputImage = filter.outputImage,
              let cgImage = context.createCGImage(outputImage, from: outputImage.extent) else {
            return nil
        }
        
        return UIImage(cgImage: cgImage)
    }
    
    func adjustContrast(image: UIImage, value: Double) -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return nil }
        
        let filter = CIFilter.colorControls()
        filter.inputImage = ciImage
        filter.contrast = Float(value)
        
        guard let outputImage = filter.outputImage,
              let cgImage = context.createCGImage(outputImage, from: outputImage.extent) else {
            return nil
        }
        
        return UIImage(cgImage: cgImage)
    }
    
    func convertToBlackAndWhite(image: UIImage) -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return nil }
        
        let filter = CIFilter.photoEffectMono()
        filter.inputImage = ciImage
        
        guard let outputImage = filter.outputImage,
              let cgImage = context.createCGImage(outputImage, from: outputImage.extent) else {
            return nil
        }
        
        return UIImage(cgImage: cgImage)
    }
    
    func applyFilters(to image: UIImage, brightness: Double, contrast: Double, blackAndWhite: Bool) -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return nil }
        
        var currentCIImage = ciImage
        
        // Apply brightness
        if brightness != 0 {
            let brightnessFilter = CIFilter.colorControls()
            brightnessFilter.inputImage = currentCIImage
            brightnessFilter.brightness = Float(brightness)
            if let outputImage = brightnessFilter.outputImage {
                currentCIImage = outputImage
            }
        }
        
        // Apply contrast
        if contrast != 1 {
            let contrastFilter = CIFilter.colorControls()
            contrastFilter.inputImage = currentCIImage
            contrastFilter.contrast = Float(contrast)
            if let outputImage = contrastFilter.outputImage {
                currentCIImage = outputImage
            }
        }
        
        // Apply black and white filter if enabled
        if blackAndWhite {
            let monoFilter = CIFilter.photoEffectMono()
            monoFilter.inputImage = currentCIImage
            if let outputImage = monoFilter.outputImage {
                currentCIImage = outputImage
            }
        }
        
        // Convert back to UIImage
        guard let cgImage = context.createCGImage(currentCIImage, from: currentCIImage.extent) else {
            return nil
        }
        
        return UIImage(cgImage: cgImage)
    }
    
    // MARK: - OCR Optimization
    
    func optimizeForOCR(_ image: UIImage) -> UIImage {
        guard let ciImage = CIImage(image: image) else { return image }
        
        var currentCIImage = ciImage
        
        // Convert to black and white
        let monoFilter = CIFilter.photoEffectMono()
        monoFilter.inputImage = currentCIImage
        if let outputImage = monoFilter.outputImage {
            currentCIImage = outputImage
        }
        
        // Increase contrast
        let contrastFilter = CIFilter.colorControls()
        contrastFilter.inputImage = currentCIImage
        contrastFilter.contrast = 1.3
        if let outputImage = contrastFilter.outputImage {
            currentCIImage = outputImage
        }
        
        // Apply sharpening
        let sharpenFilter = CIFilter.sharpenLuminance()
        sharpenFilter.inputImage = currentCIImage
        sharpenFilter.sharpness = 0.7
        if let outputImage = sharpenFilter.outputImage {
            currentCIImage = outputImage
        }
        
        // Convert back to UIImage
        guard let cgImage = context.createCGImage(currentCIImage, from: currentCIImage.extent) else {
            return image
        }
        
        return UIImage(cgImage: cgImage)
    }
    
    // MARK: - Image Caching
    
    func cacheImage(_ image: UIImage, withKey key: String) -> URL? {
        // Cache the image in memory
        imageCache.setObject(image, forKey: key as NSString)
        
        // Save to temporary file for URL access
        let fileManager = FileManager.default
        let tempDirectoryURL = fileManager.temporaryDirectory
        let fileURL = tempDirectoryURL.appendingPathComponent("\(key).jpg")
        
        if let data = image.jpegData(compressionQuality: 0.9) {
            try? data.write(to: fileURL)
            return fileURL
        }
        
        return nil
    }
    
    // MARK: - OCR Processing
    
    func performOCR(on image: UIImage, completion: @escaping (String?, Error?) -> Void) {
        guard let cgImage = image.cgImage else {
            completion(nil, NSError(domain: "ImageProcessingService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Could not get CGImage from UIImage"]))
            return
        }
        
        // Create a new image request handler
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        // Create a new request to recognize text
        let request = VNRecognizeTextRequest { request, error in
            if let error = error {
                completion(nil, error)
                return
            }
            
            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                completion(nil, NSError(domain: "ImageProcessingService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not convert results to text observations"]))
                return
            }
            
            // Process the recognized text
            let recognizedText = observations.compactMap { observation in
                observation.topCandidates(1).first?.string
            }.joined(separator: "\n")
            
            completion(recognizedText, nil)
        }
        
        // Configure the request
        request.recognitionLevel = .accurate
        
        // Perform the request
        do {
            try requestHandler.perform([request])
        } catch {
            completion(nil, error)
        }
    }
}
