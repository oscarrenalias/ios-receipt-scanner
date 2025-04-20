import Foundation
import SwiftUI
import UIKit
import AVFoundation

class CameraService: NSObject {
    static let shared = CameraService()
    
    // MARK: - Properties
    
    private var captureSession: AVCaptureSession?
    private var photoOutput: AVCapturePhotoOutput?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var photoCaptureCompletionBlock: ((UIImage?, Error?) -> Void)?
    
    // MARK: - Setup
    
    func setupCamera(in view: UIView, completion: @escaping (Bool) -> Void) {
        // First check and request permission
        PermissionsService.shared.requestCameraPermission { [weak self] granted in
            guard let self = self, granted else {
                completion(false)
                return
            }
            
            DispatchQueue.global(qos: .userInitiated).async {
                self.setupCaptureSession()
                
                DispatchQueue.main.async {
                    self.setupPreviewLayer(in: view)
                    completion(true)
                }
            }
        }
    }
    
    private func setupCaptureSession() {
        captureSession = AVCaptureSession()
        captureSession?.sessionPreset = .photo
        
        guard let captureSession = captureSession,
              let backCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            return
        }
        
        do {
            let input = try AVCaptureDeviceInput(device: backCamera)
            if captureSession.canAddInput(input) {
                captureSession.addInput(input)
            }
            
            photoOutput = AVCapturePhotoOutput()
            if let photoOutput = photoOutput, captureSession.canAddOutput(photoOutput) {
                captureSession.addOutput(photoOutput)
                photoOutput.isHighResolutionCaptureEnabled = true
            }
        } catch {
            print("Error setting up camera: \(error.localizedDescription)")
        }
    }
    
    private func setupPreviewLayer(in view: UIView) {
        guard let captureSession = captureSession else { return }
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer?.videoGravity = .resizeAspectFill
        previewLayer?.frame = view.layer.bounds
        
        if let previewLayer = previewLayer {
            view.layer.addSublayer(previewLayer)
        }
        
        startSession()
    }
    
    // MARK: - Session Control
    
    func startSession() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession?.startRunning()
        }
    }
    
    func stopSession() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession?.stopRunning()
        }
    }
    
    // MARK: - Capture Photo
    
    func capturePhoto(completion: @escaping (UIImage?, Error?) -> Void) {
        photoCaptureCompletionBlock = completion
        
        guard let photoOutput = photoOutput else {
            completion(nil, NSError(domain: "CameraService", code: 0, userInfo: [NSLocalizedDescriptionKey: "Photo output not available"]))
            return
        }
        
        let settings = AVCapturePhotoSettings()
        settings.flashMode = .auto
        settings.isHighResolutionPhotoEnabled = true
        
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    // MARK: - Orientation Handling
    
    func updatePreviewLayerFrame(to frame: CGRect) {
        previewLayer?.frame = frame
    }
    
    func updatePreviewLayerOrientation() {
        guard let connection = previewLayer?.connection, connection.isVideoOrientationSupported else { return }
        switch UIDevice.current.orientation {
        case .portrait:
            connection.videoOrientation = .portrait
        case .landscapeRight:
            connection.videoOrientation = .landscapeLeft
        case .landscapeLeft:
            connection.videoOrientation = .landscapeRight
        case .portraitUpsideDown:
            connection.videoOrientation = .portraitUpsideDown
        default:
            connection.videoOrientation = .portrait
        }
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension CameraService: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            photoCaptureCompletionBlock?(nil, error)
            return
        }
        
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            photoCaptureCompletionBlock?(nil, NSError(domain: "CameraService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not create image from photo data"]))
            return
        }
        
        photoCaptureCompletionBlock?(image, nil)
    }
}

// MARK: - SwiftUI Camera View

struct CameraView: UIViewControllerRepresentable {
    var onImageCaptured: (UIImage) -> Void
    var onDismiss: () -> Void
    
    func makeUIViewController(context: Context) -> CameraViewController {
        let controller = CameraViewController()
        controller.onImageCaptured = onImageCaptured
        controller.onDismiss = onDismiss
        return controller
    }
    
    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {}
    
    static func dismantleUIViewController(_ uiViewController: CameraViewController, coordinator: ()) {
        CameraService.shared.stopSession()
    }
}

// MARK: - Camera View Controller

class CameraViewController: UIViewController {
    var onImageCaptured: ((UIImage) -> Void)?
    var onDismiss: (() -> Void)?
    
    private let cameraPreviewView = UIView()
    private let captureButton = UIButton(type: .system)
    private let closeButton = UIButton(type: .system)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        
        // Observe device orientation changes
        NotificationCenter.default.addObserver(self, selector: #selector(orientationChanged), name: UIDevice.orientationDidChangeNotification, object: nil)
        
        CameraService.shared.setupCamera(in: cameraPreviewView) { success in
            if !success {
                self.dismiss(animated: true) {
                    self.onDismiss?()
                }
            }
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Ensure preview layer resizes with view
        CameraService.shared.updatePreviewLayerFrame(to: cameraPreviewView.bounds)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        CameraService.shared.stopSession()
        NotificationCenter.default.removeObserver(self, name: UIDevice.orientationDidChangeNotification, object: nil)
    }
    
    private func setupUI() {
        view.backgroundColor = .black
        
        // Camera preview
        cameraPreviewView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cameraPreviewView)
        NSLayoutConstraint.activate([
            cameraPreviewView.topAnchor.constraint(equalTo: view.topAnchor),
            cameraPreviewView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            cameraPreviewView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            cameraPreviewView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        // Capture button
        captureButton.translatesAutoresizingMaskIntoConstraints = false
        captureButton.setImage(UIImage(systemName: "circle.fill"), for: .normal)
        captureButton.tintColor = .white
        captureButton.contentVerticalAlignment = .fill
        captureButton.contentHorizontalAlignment = .fill
        captureButton.addTarget(self, action: #selector(capturePhoto), for: .touchUpInside)
        view.addSubview(captureButton)
        NSLayoutConstraint.activate([
            captureButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            captureButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -30),
            captureButton.widthAnchor.constraint(equalToConstant: 70),
            captureButton.heightAnchor.constraint(equalToConstant: 70)
        ])
        
        // Close button
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.setImage(UIImage(systemName: "xmark"), for: .normal)
        closeButton.tintColor = .white
        closeButton.contentVerticalAlignment = .fill
        closeButton.contentHorizontalAlignment = .fill
        closeButton.addTarget(self, action: #selector(dismissCamera), for: .touchUpInside)
        view.addSubview(closeButton)
        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            closeButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            closeButton.widthAnchor.constraint(equalToConstant: 30),
            closeButton.heightAnchor.constraint(equalToConstant: 30)
        ])
    }
    
    @objc private func capturePhoto() {
        CameraService.shared.capturePhoto { [weak self] image, error in
            guard let self = self, let image = image else {
                print("Error capturing photo: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            
            self.dismiss(animated: true) {
                self.onImageCaptured?(image)
            }
        }
    }
    
    @objc private func dismissCamera() {
        dismiss(animated: true) {
            self.onDismiss?()
        }
    }
    
    @objc private func orientationChanged() {
        CameraService.shared.updatePreviewLayerOrientation()
    }
}
