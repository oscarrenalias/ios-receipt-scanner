import UIKit
import Vision

class OCRService {
    static func recognizeText(from image: UIImage, completion: @escaping (String?) -> Void) {
        guard let cgImage = image.cgImage else {
            completion(nil)
            return
        }
        
        // Create a new image request handler
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        // Create a new request to recognize text
        let request = VNRecognizeTextRequest { request, error in
            if let error = error {
                print("OCR error: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                completion(nil)
                return
            }
            
            // Process the recognized text
            let recognizedText = observations.compactMap { observation in
                observation.topCandidates(1).first?.string
            }.joined(separator: "\n")
            
            completion(recognizedText.isEmpty ? nil : recognizedText)
        }
        
        // Configure the request
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        
        // Perform the request
        do {
            try requestHandler.perform([request])
        } catch {
            print("OCR request failed: \(error.localizedDescription)")
            completion(nil)
        }
    }
}
