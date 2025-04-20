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
    private var currentZoomFactor: CGFloat = 1.0
    private var minZoomFactor: CGFloat = 1.0
    private var maxZoomFactor: CGFloat = 5.0
    
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
    
    // MARK: - Zoom Handling
    
    func setZoom(factor: CGFloat) {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else { return }
        do {
            try device.lockForConfiguration()
            let zoom = max(minZoomFactor, min(factor, device.activeFormat.videoMaxZoomFactor, maxZoomFactor))
            device.videoZoomFactor = zoom
            currentZoomFactor = zoom
            device.unlockForConfiguration()
        } catch {
            print("Failed to set zoom: \(error)")
        }
    }
    
    func getCurrentZoomFactor() -> CGFloat {
        return currentZoomFactor
    }
    
    func getMaxZoomFactor() -> CGFloat {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else { return 5.0 }
        return min(device.activeFormat.videoMaxZoomFactor, maxZoomFactor)
    }
    
    func getMinZoomFactor() -> CGFloat {
        return minZoomFactor
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
    private let zoomLabel = UILabel()
    private var pinchGesture: UIPinchGestureRecognizer!
    private var doubleTapGesture: UITapGestureRecognizer!
    
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
        
        // Add pinch gesture for zoom
        pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        cameraPreviewView.addGestureRecognizer(pinchGesture)
        
        // Add double-tap gesture for focus
        doubleTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTapGesture.numberOfTapsRequired = 2
        cameraPreviewView.addGestureRecognizer(doubleTapGesture)
        
        // Setup zoom label
        setupZoomLabel()
        updateZoomLabel()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Ensure preview layer resizes with view
        CameraService.shared.updatePreviewLayerFrame(to: cameraPreviewView.bounds)
        self.view.bringSubviewToFront(zoomLabel)
        updateZoomLabel()
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
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            closeButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            closeButton.widthAnchor.constraint(equalToConstant: 30),
            closeButton.heightAnchor.constraint(equalToConstant: 30)
        ])
    }
    
    private func setupZoomLabel() {
        zoomLabel.translatesAutoresizingMaskIntoConstraints = false
        zoomLabel.textColor = .white
        zoomLabel.font = UIFont.boldSystemFont(ofSize: 18)
        zoomLabel.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        zoomLabel.layer.cornerRadius = 8
        zoomLabel.clipsToBounds = true
        zoomLabel.textAlignment = .center
        self.view.addSubview(zoomLabel)
        NSLayoutConstraint.activate([
            zoomLabel.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor, constant: 16),
            zoomLabel.trailingAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            zoomLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 44),
            zoomLabel.heightAnchor.constraint(equalToConstant: 32)
        ])
        self.view.bringSubviewToFront(zoomLabel)
    }
    
    private func updateZoomLabel() {
        let zoom = CameraService.shared.getCurrentZoomFactor()
        zoomLabel.text = String(format: "%.1fx", zoom)
    }
    
    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else { return }
        if gesture.state == .began || gesture.state == .changed {
            let maxZoom = CameraService.shared.getMaxZoomFactor()
            let minZoom = CameraService.shared.getMinZoomFactor()
            var newZoom = device.videoZoomFactor * gesture.scale
            newZoom = max(minZoom, min(newZoom, maxZoom))
            CameraService.shared.setZoom(factor: newZoom)
            updateZoomLabel()
            gesture.scale = 1.0
        }
    }
    
    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: cameraPreviewView)
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else { return }
        let focusPoint = CGPoint(x: location.x / cameraPreviewView.bounds.width, y: location.y / cameraPreviewView.bounds.height)
        do {
            try device.lockForConfiguration()
            if device.isFocusPointOfInterestSupported {
                device.focusPointOfInterest = focusPoint
                device.focusMode = .autoFocus
            }
            if device.isExposurePointOfInterestSupported {
                device.exposurePointOfInterest = focusPoint
                device.exposureMode = .autoExpose
            }
            device.unlockForConfiguration()
        } catch {
            print("Failed to set focus/exposure: \(error)")
        }
        // Optional: add a quick visual feedback for focus
        showFocusIndicator(at: location)
    }
    
    private func showFocusIndicator(at point: CGPoint) {
        let indicator = UIView(frame: CGRect(x: 0, y: 0, width: 60, height: 60))
        indicator.center = point
        indicator.layer.borderColor = UIColor.yellow.cgColor
        indicator.layer.borderWidth = 2
        indicator.layer.cornerRadius = 30
        indicator.backgroundColor = UIColor.clear
        cameraPreviewView.addSubview(indicator)
        UIView.animate(withDuration: 0.7, animations: {
            indicator.alpha = 0
        }) { _ in
            indicator.removeFromSuperview()
        }
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
