import SwiftUI
import PhotosUI

struct ScannerView: View {
    @State private var showingCamera = false
    @State private var showingPhotoPicker = false
    @State private var scannedImage: UIImage?
    @State private var isProcessingImage = false
    @State private var photoPickerItems: [PhotosPickerItem] = []
    
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
                        }
                    }
                case .failure(let error):
                    print("Photo picker error: \(error)")
                }
            }
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
                showingPhotoPicker = true
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
