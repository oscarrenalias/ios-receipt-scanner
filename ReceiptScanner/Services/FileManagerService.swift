import Foundation
import UIKit

class FileManagerService {
    static let shared = FileManagerService()
    
    private let fileManager = FileManager.default
    
    private init() {}
    
    // MARK: - Document Directory
    
    func getDocumentsDirectory() -> URL {
        return fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    // MARK: - Save and Load Images
    
    func saveImage(_ image: UIImage, withName name: String) -> URL? {
        let fileName = name.hasSuffix(".jpg") ? name : "\(name).jpg"
        let fileURL = getDocumentsDirectory().appendingPathComponent(fileName)
        
        guard let data = image.jpegData(compressionQuality: 0.8) else { return nil }
        
        do {
            try data.write(to: fileURL)
            return fileURL
        } catch {
            print("Error saving image: \(error.localizedDescription)")
            return nil
        }
    }
    
    func loadImage(from url: URL) -> UIImage? {
        do {
            let data = try Data(contentsOf: url)
            return UIImage(data: data)
        } catch {
            print("Error loading image: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - Save and Load Text
    
    func saveText(_ text: String, withName name: String) -> URL? {
        let fileName = name.hasSuffix(".txt") ? name : "\(name).txt"
        let fileURL = getDocumentsDirectory().appendingPathComponent(fileName)
        
        do {
            try text.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            print("Error saving text: \(error.localizedDescription)")
            return nil
        }
    }
    
    func loadText(from url: URL) -> String? {
        do {
            return try String(contentsOf: url, encoding: .utf8)
        } catch {
            print("Error loading text: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - File Management
    
    func deleteFile(at url: URL) -> Bool {
        do {
            try fileManager.removeItem(at: url)
            return true
        } catch {
            print("Error deleting file: \(error.localizedDescription)")
            return false
        }
    }
    
    func fileExists(at url: URL) -> Bool {
        return fileManager.fileExists(atPath: url.path)
    }
    
    func listFiles(withExtension ext: String? = nil) -> [URL] {
        do {
            let directoryContents = try fileManager.contentsOfDirectory(
                at: getDocumentsDirectory(),
                includingPropertiesForKeys: nil
            )
            
            if let ext = ext {
                return directoryContents.filter { $0.pathExtension == ext }
            } else {
                return directoryContents
            }
        } catch {
            print("Error listing files: \(error.localizedDescription)")
            return []
        }
    }
}
