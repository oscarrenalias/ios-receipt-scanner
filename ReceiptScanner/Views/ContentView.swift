import SwiftUI
import SDWebImageSwiftUI

struct ContentView: View {
    @State private var showingImagePicker = false
    @State private var showingCamera = false
    @State private var inputImage: UIImage?
    @State private var processedImage: UIImage?
    @State private var navigateToEditor = false
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // App logo with animated WebImage
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 120, height: 120)
                    
                    Image(systemName: "doc.text.viewfinder")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 60, height: 60)
                        .foregroundColor(.blue)
                }
                
                Text("Receipt Scanner")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                VStack(spacing: 20) {
                    Button(action: {
                        self.showingCamera = true
                    }) {
                        HStack {
                            Image(systemName: "camera")
                                .font(.title)
                            Text("Scan Receipt")
                                .fontWeight(.semibold)
                                .font(.title3)
                        }
                        .frame(minWidth: 0, maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    
                    Button(action: {
                        self.showingImagePicker = true
                    }) {
                        HStack {
                            Image(systemName: "photo.on.rectangle")
                                .font(.title)
                            Text("Choose from Library")
                                .fontWeight(.semibold)
                                .font(.title3)
                        }
                        .frame(minWidth: 0, maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    
                    if isLoading {
                        ProgressView("Processing...")
                            .progressViewStyle(CircularProgressViewStyle())
                            .padding()
                    }
                }
                .padding(.horizontal)
                
                NavigationLink(
                    destination: EnhancedImageEditorView(image: inputImage ?? UIImage()),
                    isActive: $navigateToEditor
                ) {
                    EmptyView()
                }
            }
            .padding()
            .navigationBarTitle("", displayMode: .inline)
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(image: self.$inputImage, sourceType: .photoLibrary, onImageSelected: {
                    self.processImage()
                })
            }
            .sheet(isPresented: $showingCamera) {
                ImagePicker(image: self.$inputImage, sourceType: .camera, onImageSelected: {
                    self.processImage()
                })
            }
        }
    }
    
    private func processImage() {
        guard let image = inputImage else { return }
        
        isLoading = true
        
        // Process image in background
        DispatchQueue.global(qos: .userInitiated).async {
            // Apply initial enhancements
            let enhancedImage = ImageProcessingService.shared.enhanceReceiptImage(image)
            self.inputImage = enhancedImage
            
            // Update UI on main thread
            DispatchQueue.main.async {
                self.isLoading = false
                self.navigateToEditor = true
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
