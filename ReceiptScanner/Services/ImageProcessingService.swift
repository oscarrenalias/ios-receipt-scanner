import Foundation
import UIKit
import SDWebImage

// Extension to make filter configuration cleaner
extension CIFilter {
    func apply(_ closure: (CIFilter) -> Void) -> CIFilter {
        closure(self)
        return self
    }
}

class ImageProcessingService {
    static let shared = ImageProcessingService()
    
    private let imageCache = SDImageCache.shared
    
    private init() {}
    
    // Save image to SDWebImage cache with a unique key
    func cacheImage(_ image: UIImage, withKey key: String) -> URL? {
        let cacheKey = "receipt_\(key)"
        if let imageData = image.jpegData(compressionQuality: 0.8) {
            imageCache.storeImageData(imageData, forKey: cacheKey)
        }
        
        // Create a fake URL that can be used with SDWebImage
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        
        return documentsDirectory.appendingPathComponent(cacheKey)
    }
    
    // Apply advanced image processing using SDWebImage's capabilities
    func enhanceReceiptImage(_ image: UIImage) -> UIImage {
        // Create a processing pipeline using SDWebImage's transformers
        let transformer = SDImagePipelineTransformer(transformers: [
            SDImageFilterTransformer(filter: CIFilter(name: "CIColorControls")!.apply { $0.setValue(1.2, forKey: "inputContrast") }),  // Increase contrast
            SDImageFilterTransformer(filter: CIFilter(name: "CIColorControls")!.apply { $0.setValue(0.1, forKey: "inputBrightness") }),  // Slightly increase brightness
            SDImageFilterTransformer(filter: CIFilter(name: "CISharpenLuminance")!.apply { $0.setValue(0.5, forKey: "inputSharpness") }),  // Sharpen
        ])
        
        // Process the image
        if let processedImage = transformer.transformedImage(with: image, forKey: "notneeded") {
            return processedImage
        }
        
        return image
    }
    
    // Apply receipt-specific optimizations
    func optimizeForOCR(_ image: UIImage) -> UIImage {
        // Create a processing pipeline specifically for OCR
        let transformer = SDImagePipelineTransformer(transformers: [
            // Convert to grayscale for better OCR
            SDImageFilterTransformer(filter: CIFilter(name: "CIPhotoEffectMono")!),
            // Increase contrast to make text more readable
            SDImageFilterTransformer(filter: CIFilter(name: "CIColorControls")!.apply { $0.setValue(1.4, forKey: "inputContrast") }),
            // Apply adaptive thresholding for better text extraction
            SDImageFilterTransformer(filter: CIFilter(name: "CIColorThreshold")!.apply { $0.setValue(0.5, forKey: "inputThreshold") }),
        ])
        
        // Process the image
        if let processedImage = transformer.transformedImage(with: image, forKey: "notneeded") {
            return processedImage
        }
        
        return image
    }
    
    // Clear cached images
    func clearCache() {
        imageCache.clearMemory()
        imageCache.clearDisk()
    }
}
