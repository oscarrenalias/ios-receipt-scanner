import SwiftUI
import PhotosUI

struct ScannerView: View {
    @State private var showingCamera = false
    @State private var showingPhotoPicker = false
    @State private var showingImageEditor = false
    @State private var scannedImage: UIImage?
    @State private var processedImage: UIImage?
    @State private var photoPickerItems: [PhotosPickerItem] = []
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
                            }
                        }
                    case .failure(let error):
                        print("Photo picker error: \(error)")
                    }
                }
            }
            .fullScreenCover(isPresented: $showingImageEditor) {
                if let image = scannedImage {
                    ImageEditorView(image: image) { editedImage in
                        self.processedImage = editedImage
                    }
                }
            }
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
                UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                
                // Show a success message
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
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
