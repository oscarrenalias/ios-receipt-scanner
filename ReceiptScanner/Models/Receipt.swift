import Foundation
import UIKit

struct Receipt: Identifiable, Codable {
    var id = UUID()
    var title: String
    var date: Date
    var totalAmount: Double?
    var vendor: String?
    var category: ReceiptCategory
    var notes: String?
    var imageFilename: String
    
    enum ReceiptCategory: String, Codable, CaseIterable {
        case grocery = "Grocery"
        case restaurant = "Restaurant"
        case transportation = "Transportation"
        case utilities = "Utilities"
        case entertainment = "Entertainment"
        case healthcare = "Healthcare"
        case other = "Other"
    }
    
    // This property is not stored, just for in-memory use
    var image: UIImage? {
        get {
            let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let fileURL = documentsDirectory.appendingPathComponent(imageFilename)
            return UIImage(contentsOfFile: fileURL.path)
        }
        set {
            if let newImage = newValue, let data = newImage.jpegData(compressionQuality: 0.8) {
                let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                let filename = "\(id.uuidString).jpg"
                let fileURL = documentsDirectory.appendingPathComponent(filename)
                
                try? data.write(to: fileURL)
                imageFilename = filename
            }
        }
    }
}
