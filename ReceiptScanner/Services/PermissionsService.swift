import Foundation
import AVFoundation
import Photos
import UIKit

class PermissionsService {
    static let shared = PermissionsService()
    
    private init() {}
    
    // MARK: - Camera Permissions
    
    func requestCameraPermission(completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    completion(granted)
                }
            }
        case .denied, .restricted:
            completion(false)
            showPermissionAlert(for: .camera)
        @unknown default:
            completion(false)
        }
    }
    
    // MARK: - Photo Library Permissions
    
    func requestPhotoLibraryPermission(completion: @escaping (Bool) -> Void) {
        switch PHPhotoLibrary.authorizationStatus() {
        case .authorized:
            completion(true)
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization { status in
                DispatchQueue.main.async {
                    completion(status == .authorized)
                }
            }
        case .denied, .restricted, .limited:
            completion(false)
            showPermissionAlert(for: .photoLibrary)
        @unknown default:
            completion(false)
        }
    }
    
    // MARK: - Photo Library Add-Only Permissions
    
    func requestPhotoLibraryAddOnlyPermission(completion: @escaping (Bool) -> Void) {
        switch PHPhotoLibrary.authorizationStatus(for: .addOnly) {
        case .authorized:
            completion(true)
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                DispatchQueue.main.async {
                    completion(status == .authorized)
                }
            }
        case .denied, .restricted, .limited:
            completion(false)
            showPermissionAlert(for: .photoLibraryAddOnly)
        @unknown default:
            completion(false)
        }
    }
    
    // MARK: - Helper Methods
    
    private enum PermissionType {
        case camera
        case photoLibrary
        case photoLibraryAddOnly
        
        var title: String {
            switch self {
            case .camera:
                return "Camera Access Required"
            case .photoLibrary:
                return "Photo Library Access Required"
            case .photoLibraryAddOnly:
                return "Photo Library Access Required"
            }
        }
        
        var message: String {
            switch self {
            case .camera:
                return "Please enable camera access in Settings to scan receipts."
            case .photoLibrary:
                return "Please enable photo library access in Settings to import and save images."
            case .photoLibraryAddOnly:
                return "Please enable photo library access in Settings to save processed receipts."
            }
        }
    }
    
    private func showPermissionAlert(for type: PermissionType) {
        let alert = UIAlertController(
            title: type.title,
            message: type.message,
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Settings", style: .default) { _ in
            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsURL)
            }
        })
        
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
}
