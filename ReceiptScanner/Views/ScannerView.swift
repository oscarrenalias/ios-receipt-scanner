import SwiftUI
import PhotosUI
import UIKit

class ImageSaver: NSObject {
    var successHandler: (() -> Void)?
    var errorHandler: ((Error) -> Void)?
    
    @objc func image(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        if let error = error {
            errorHandler?(error)
        } else {
            successHandler?()
        }
    }
}

struct ScannerView: View {
    private let imageSaver = ImageSaver()
    @State private var showingCamera = false
    @State private var showingPhotoPicker = false
    @State private var showingImageEditor = false
    @State private var scannedImage: UIImage?
    @State private var processedImage: UIImage?
    @State private var photoPickerItems: [PhotosPickerItem] = []
    @State private var showingSaveConfirmation = false
    @State private var saveConfirmationMessage = ""
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        NavigationView {
            ZStack(alignment: .bottom) {
                // Main content
                VStack(spacing: 20) {
                    if let image = processedImage ?? scannedImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 400)
                            .cornerRadius(10)
                            .shadow(radius: 5)
                            .onTapGesture {
                                if let _ = scannedImage {
                                    showingImageEditor = true
                                }
                            }
                        
                        Button(action: {
                            saveImageToPhotoLibrary()
                        }) {
                            Label("Save to Photos", systemImage: "square.and.arrow.down")
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                                .shadow(radius: 2)
                        }
                        .padding(.horizontal)
                    } else {
                        VStack {
                            Image(systemName: "doc.text.viewfinder")
                                .resizable()
                                .scaledToFit()
                                .frame(height: 150)
                                .foregroundColor(.secondary)
                                .padding()
                            
                            Text("No receipt scanned yet")
                                .foregroundColor(.secondary)
                                .italic()
                                .padding(.bottom, 20)
                            
                            Text("Tap the camera icon below to scan a receipt or select one from your photo library")
                                .multilineTextAlignment(.center)
                                .foregroundColor(.secondary)
                                .font(.callout)
                                .padding(.horizontal, 40)
                        }
                        .frame(maxHeight: .infinity)
                    }
                    
                    Spacer()
                }
                .padding(.bottom, 80) // Make room for the tab bar
                
                // Custom tab bar
                VStack(spacing: 0) {
                    Divider()
                    
                    HStack(spacing: 0) {
                        // Camera button
                        Button(action: {
                            requestCameraAccess()
                        }) {
                            VStack(spacing: 4) {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 24))
                                Text("Scan")
                                    .font(.caption)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                        }
                        .foregroundColor(.blue)
                        
                        // Photo library button
                        Button(action: {
                            requestPhotoLibraryAccess()
                        }) {
                            VStack(spacing: 4) {
                                Image(systemName: "photo.on.rectangle")
                                    .font(.system(size: 24))
                                Text("Import")
                                    .font(.caption)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                        }
                        .foregroundColor(.blue)
                    }
                }
                .background(
                    colorScheme == .dark ? 
                        Color(UIColor.systemBackground).opacity(0.9) : 
                        Color(UIColor.systemBackground).opacity(0.95)
                )
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: -5)
            }
            .navigationBarTitleDisplayMode(.inline)
            .fullScreenCover(isPresented: $showingCamera) {
                CameraView(
                    onImageCaptured: { image in
                        self.scannedImage = image
                        self.processedImage = nil
                        self.showingImageEditor = true
                        print("🔍 ScannerView: Showing EnhancedImageEditorView from camera")
                    },
                    onDismiss: {
                        showingCamera = false
                    }
                )
            }
            .photosPicker(
                isPresented: $showingPhotoPicker,
                selection: $photoPickerItems,
                maxSelectionCount: 1,
                matching: .images
            )
            .onChange(of: photoPickerItems) { newItems in
                guard let item = newItems.first else { return }
                
                item.loadTransferable(type: Data.self) { result in
                    switch result {
                    case .success(let data):
                        if let data = data, let image = UIImage(data: data) {
                            DispatchQueue.main.async {
                                self.scannedImage = image
                                self.processedImage = nil
                                self.showingImageEditor = true
                                print("🔍 ScannerView: Showing EnhancedImageEditorView from photo library")
                            }
                        }
                    case .failure(let error):
                        print("Photo picker error: \(error)")
                    }
                }
            }
            .fullScreenCover(isPresented: $showingImageEditor) {
                if let image = scannedImage {
                    EnhancedImageEditorView(image: image)
                }
            }
            .overlay(
                Group {
                    if showingSaveConfirmation {
                        VStack {
                            Spacer()
                            
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.title)
                                
                                Text(saveConfirmationMessage)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(colorScheme == .dark ? 
                                          Color(UIColor.systemGray6) : 
                                          Color(UIColor.systemBackground))
                                    .shadow(color: Color.black.opacity(0.2), radius: 5)
                            )
                            .padding(.bottom, 100) // Position above the tab bar
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                            .animation(.easeInOut, value: showingSaveConfirmation)
                        }
                    }
                }
            )
        }
        .preferredColorScheme(colorScheme) // Preserve the current color scheme
    }
    
    private func requestCameraAccess() {
        PermissionsService.shared.requestCameraPermission { granted in
            if granted {
                showingCamera = true
            }
            // The PermissionsService will handle showing the alert if permission is denied
        }
    }
    
    private func requestPhotoLibraryAccess() {
        PermissionsService.shared.requestPhotoLibraryPermission { granted in
            if granted {
                showingPhotoPicker = true
            }
            // The PermissionsService will handle showing the alert if permission is denied
        }
    }
    
    private func saveImageToPhotoLibrary() {
        guard let image = processedImage ?? scannedImage else { return }
        
        PermissionsService.shared.requestPhotoLibraryAddOnlyPermission { granted in
            if granted {
                // Configure the image saver
                self.imageSaver.successHandler = {
                    DispatchQueue.main.async {
                        self.saveConfirmationMessage = "Receipt saved to your photo library!"
                        self.showingSaveConfirmation = true
                        
                        // Provide haptic feedback
                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.success)
                        
                        // Auto-dismiss after 2 seconds
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            self.showingSaveConfirmation = false
                        }
                    }
                }
                
                self.imageSaver.errorHandler = { error in
                    DispatchQueue.main.async {
                        self.saveConfirmationMessage = "Error saving image: \(error.localizedDescription)"
                        self.showingSaveConfirmation = true
                        
                        // Provide error feedback
                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.error)
                        
                        // Auto-dismiss after 3 seconds
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            self.showingSaveConfirmation = false
                        }
                    }
                }
                
                // Save the image
                UIImageWriteToSavedPhotosAlbum(image, self.imageSaver, #selector(ImageSaver.image(_:didFinishSavingWithError:contextInfo:)), nil)
            }
            // The PermissionsService will handle showing the alert if permission is denied
        }
    }
}

// Preview with both light and dark mode
struct ScannerView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ScannerView()
                .preferredColorScheme(.light)
                .previewDisplayName("Light Mode")
            
            ScannerView()
                .preferredColorScheme(.dark)
                .previewDisplayName("Dark Mode")
        }
    }
}
