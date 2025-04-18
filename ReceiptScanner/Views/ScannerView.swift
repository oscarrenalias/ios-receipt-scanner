import SwiftUI

struct ScannerView: View {
    @State private var showingCamera = false
    @State private var scannedImage: UIImage?
    @State private var isProcessingImage = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Receipt Scanner")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            if let image = scannedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 400)
                    .cornerRadius(10)
                    .shadow(radius: 5)
                
                HStack(spacing: 20) {
                    Button("Process Receipt") {
                        isProcessingImage = true
                        // Here you would add your image processing logic
                        // For now, we'll just simulate processing
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                            isProcessingImage = false
                        }
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .disabled(isProcessingImage)
                    
                    Button("Save to Photos") {
                        saveImageToPhotoLibrary()
                    }
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
            } else {
                Image(systemName: "doc.text.viewfinder")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 200)
                    .foregroundColor(.gray)
                    .padding()
                
                Text("No receipt scanned yet")
                    .foregroundColor(.gray)
                    .italic()
            }
            
            Spacer()
            
            HStack(spacing: 20) {
                Button("Scan Receipt") {
                    requestCameraAccess()
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
                
                Button("Import from Photos") {
                    requestPhotoLibraryAccess()
                }
                .padding()
                .background(Color.orange)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
        }
        .padding()
        .fullScreenCover(isPresented: $showingCamera) {
            CameraView(
                onImageCaptured: { image in
                    self.scannedImage = image
                },
                onDismiss: {
                    showingCamera = false
                }
            )
        }
        .overlay(
            Group {
                if isProcessingImage {
                    ZStack {
                        Color.black.opacity(0.4)
                        VStack {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text("Processing image...")
                                .foregroundColor(.white)
                                .padding(.top)
                        }
                    }
                    .edgesIgnoringSafeArea(.all)
                }
            }
        )
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
                // Here you would show a photo picker
                // For now, we'll just print a message
                print("Photo library access granted")
            }
            // The PermissionsService will handle showing the alert if permission is denied
        }
    }
    
    private func saveImageToPhotoLibrary() {
        guard let image = scannedImage else { return }
        
        PermissionsService.shared.requestPhotoLibraryAddOnlyPermission { granted in
            if granted {
                UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
                // You could show a success message here
            }
            // The PermissionsService will handle showing the alert if permission is denied
        }
    }
}

#Preview {
    ScannerView()
}
