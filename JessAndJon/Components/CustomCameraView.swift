import SwiftUI
import AVFoundation
import UIKit

struct CustomCameraView: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) var dismiss
    
    func makeUIViewController(context: Context) -> CameraViewController {
        let controller = CameraViewController()
        controller.delegate = context.coordinator
        return controller
    }
    
    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, CameraViewControllerDelegate {
        let parent: CustomCameraView
        
        init(_ parent: CustomCameraView) {
            self.parent = parent
        }
        
        func didCaptureImage(_ image: UIImage) {
            // Image is already cropped to square by the camera view
            parent.image = image
            parent.dismiss()
        }
        
        func didCancel() {
            parent.dismiss()
        }
    }
}

protocol CameraViewControllerDelegate: AnyObject {
    func didCaptureImage(_ image: UIImage)
    func didCancel()
}

class CameraViewController: UIViewController {
    weak var delegate: CameraViewControllerDelegate?
    
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var photoOutput: AVCapturePhotoOutput?
    private var videoInput: AVCaptureDeviceInput?
    private var currentCameraPosition: AVCaptureDevice.Position = .back
    
    private let previewContainer = UIView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
        setupUI()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startSession()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopSession()
    }
    
    private func setupCamera() {
        let session = AVCaptureSession()
        session.sessionPreset = .photo
        
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: currentCameraPosition) else {
            print("Camera not available")
            return
        }
        
        do {
            let input = try AVCaptureDeviceInput(device: camera)
            if session.canAddInput(input) {
                session.addInput(input)
                videoInput = input
            }
            
            let output = AVCapturePhotoOutput()
            if session.canAddOutput(output) {
                session.addOutput(output)
                photoOutput = output
            }
            
            captureSession = session
        } catch {
            print("Error setting up camera: \(error)")
        }
    }
    
    private func switchCamera() {
        guard let session = captureSession,
              let currentInput = videoInput else { return }
        
        session.beginConfiguration()
        session.removeInput(currentInput)
        
        // Switch camera position
        currentCameraPosition = currentCameraPosition == .back ? .front : .back
        
        guard let newCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: currentCameraPosition) else {
            session.addInput(currentInput) // Revert if new camera not available
            session.commitConfiguration()
            return
        }
        
        do {
            let newInput = try AVCaptureDeviceInput(device: newCamera)
            if session.canAddInput(newInput) {
                session.addInput(newInput)
                videoInput = newInput
            } else {
                session.addInput(currentInput) // Revert if can't add
            }
        } catch {
            print("Error switching camera: \(error)")
            session.addInput(currentInput) // Revert on error
        }
        
        session.commitConfiguration()
        
        // Set video orientation to portrait for both cameras
        updateVideoOrientation()
    }
    
    private func updateVideoOrientation() {
        // Set preview layer to portrait orientation
        if let connection = previewLayer?.connection, connection.isVideoOrientationSupported {
            connection.videoOrientation = .portrait
        }
        
        // Also set photo output orientation if available
        if let photoOutput = photoOutput, let connection = photoOutput.connection(with: .video) {
            if connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait
            }
        }
    }
    
    private func setupUI() {
        view.backgroundColor = .black
        
        // Preview container - square viewfinder (this is what user sees)
        previewContainer.translatesAutoresizingMaskIntoConstraints = false
        previewContainer.clipsToBounds = true
        previewContainer.layer.cornerRadius = 0 // Square, no rounding
        view.addSubview(previewContainer)
        
        // Buttons container
        let buttonContainer = UIView()
        buttonContainer.backgroundColor = .clear
        buttonContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(buttonContainer)
        
        // Cancel button
        let cancelButton = UIButton(type: .system)
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.setTitleColor(.white, for: .normal)
        cancelButton.titleLabel?.font = .systemFont(ofSize: 18, weight: .medium)
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        buttonContainer.addSubview(cancelButton)
        
        // Flip camera button
        let flipButton = UIButton(type: .system)
        flipButton.setImage(UIImage(systemName: "camera.rotate"), for: .normal)
        flipButton.tintColor = .white
        flipButton.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        flipButton.layer.cornerRadius = 25
        flipButton.addTarget(self, action: #selector(flipCameraTapped), for: .touchUpInside)
        flipButton.translatesAutoresizingMaskIntoConstraints = false
        buttonContainer.addSubview(flipButton)
        
        // Capture button
        let captureButton = UIButton(type: .custom)
        captureButton.backgroundColor = .white
        captureButton.layer.cornerRadius = 35
        captureButton.layer.borderWidth = 4
        captureButton.layer.borderColor = UIColor.white.cgColor
        captureButton.addTarget(self, action: #selector(captureTapped), for: .touchUpInside)
        captureButton.translatesAutoresizingMaskIntoConstraints = false
        buttonContainer.addSubview(captureButton)
        
        // Setup preview layer - this will fill the square container
        if let session = captureSession {
            let preview = AVCaptureVideoPreviewLayer(session: session)
            preview.videoGravity = .resizeAspectFill // Fill the square container
            
            // Set portrait orientation
            if let connection = preview.connection, connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait
            }
            
            previewContainer.layer.addSublayer(preview)
            previewLayer = preview
        }
        
        // Constraints
        NSLayoutConstraint.activate([
            // Preview container - square, centered, fills most of screen
            previewContainer.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.85),
            previewContainer.heightAnchor.constraint(equalTo: previewContainer.widthAnchor), // Square
            previewContainer.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            previewContainer.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -50),
            
            // Button container
            buttonContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            buttonContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            buttonContainer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            buttonContainer.heightAnchor.constraint(equalToConstant: 80),
            
            // Cancel button
            cancelButton.leadingAnchor.constraint(equalTo: buttonContainer.leadingAnchor, constant: 20),
            cancelButton.centerYAnchor.constraint(equalTo: buttonContainer.centerYAnchor),
            
            // Flip camera button
            flipButton.trailingAnchor.constraint(equalTo: buttonContainer.trailingAnchor, constant: -20),
            flipButton.centerYAnchor.constraint(equalTo: buttonContainer.centerYAnchor),
            flipButton.widthAnchor.constraint(equalToConstant: 50),
            flipButton.heightAnchor.constraint(equalToConstant: 50),
            
            // Capture button
            captureButton.centerXAnchor.constraint(equalTo: buttonContainer.centerXAnchor),
            captureButton.centerYAnchor.constraint(equalTo: buttonContainer.centerYAnchor),
            captureButton.widthAnchor.constraint(equalToConstant: 70),
            captureButton.heightAnchor.constraint(equalToConstant: 70)
        ])
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Make preview layer fill the square container exactly
        previewLayer?.frame = previewContainer.bounds
        // Ensure orientation is maintained after layout
        updateVideoOrientation()
    }
    
    private func startSession() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession?.startRunning()
        }
    }
    
    private func stopSession() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession?.stopRunning()
        }
    }
    
    @objc private func cancelTapped() {
        delegate?.didCancel()
    }
    
    @objc private func flipCameraTapped() {
        switchCamera()
    }
    
    @objc private func captureTapped() {
        guard let photoOutput = photoOutput else { return }
        
        let settings = AVCapturePhotoSettings()
        // Use default settings - will use HEIF if available, JPEG otherwise
        // This ensures compatibility a  cross all iOS versions
        
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
}

extension CameraViewController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            print("Failed to get image from photo")
            return
        }
        
        // Important: Wait for layout to ensure previewContainer.bounds is correct
        view.layoutIfNeeded()
        
        // Debug: Print image and preview info
        let imageSize = image.size
        let previewSize = previewLayer?.bounds.size ?? .zero
        print("📸 Captured image size: \(imageSize), Preview size: \(previewSize), Image aspect: \(String(format: "%.2f", imageSize.width/imageSize.height))")
        
        // Crop to square (matching exactly what's shown in the preview)
        let croppedImage = cropToSquare(image: image)
        
        // Debug: Print crop result
        let croppedSize = croppedImage.size
        print("✂️ Cropped image size: \(croppedSize), Aspect: \(String(format: "%.2f", croppedSize.width/croppedSize.height))")
        
        delegate?.didCaptureImage(croppedImage)
    }
    
    private func cropToSquare(image: UIImage) -> UIImage {
        // Calculate crop based on how .resizeAspectFill works in a square container
        // This is the most reliable method that matches what's shown in the preview
        guard let cgImage = image.cgImage else {
            print("⚠️ No CGImage available")
            return cropToSquareFallback(image: image)
        }
        
        // Use UIImage.size which accounts for orientation (what user sees in preview)
        // This is what the preview shows, so we should crop based on this
        let imageSize = image.size
        let imageAspect = imageSize.width / imageSize.height
        
        // CGImage dimensions (actual pixel data, may be swapped due to orientation)
        let cgWidth = CGFloat(cgImage.width)
        let cgHeight = CGFloat(cgImage.height)
        
        // Preview container is square (1:1 aspect ratio)
        // With .resizeAspectFill, the image is scaled to fill the square
        // The smaller dimension determines the scale factor
        
        let cropRect: CGRect
        
        if imageAspect < 1.0 {
            // UIImage.size shows portrait (taller than wide, like 3024x4032)
            // Preview scales to fill width, crops top/bottom
            // Visible: full width, center portion vertically (square = width)
            // For CGImage, we need to find which dimension corresponds to "width" in UIImage
            let cropSize = min(cgWidth, cgHeight) // Square = smaller CGImage dimension
            let offset = (max(cgWidth, cgHeight) - cropSize) / 2
            
            // CGImage might be swapped - if CGImage is landscape but UIImage is portrait,
            // we crop horizontally in CGImage (which is vertical in UIImage)
            if cgWidth > cgHeight {
                // CGImage is landscape, but UIImage displays as portrait
                // Crop horizontally in CGImage (which is vertical in displayed image)
                cropRect = CGRect(x: offset, y: 0, width: cropSize, height: cropSize)
            } else {
                // CGImage is portrait, matches UIImage
                // Crop vertically in CGImage
                cropRect = CGRect(x: 0, y: offset, width: cropSize, height: cropSize)
            }
            
            print("📐 Portrait crop: size=\(cropSize), CGImage=(\(cgWidth), \(cgHeight)), UIImage.size=\(imageSize)")
        } else {
            // UIImage.size shows landscape (wider than tall)
            // Preview scales to fill height, crops left/right
            // Visible: full height, center portion horizontally (square = height)
            let cropSize = min(cgWidth, cgHeight) // Square = smaller CGImage dimension
            let offset = (max(cgWidth, cgHeight) - cropSize) / 2
            
            // CGImage might be swapped - if CGImage is portrait but UIImage is landscape,
            // we crop vertically in CGImage (which is horizontal in UIImage)
            if cgWidth < cgHeight {
                // CGImage is portrait, but UIImage displays as landscape
                // Crop vertically in CGImage (which is horizontal in displayed image)
                cropRect = CGRect(x: 0, y: offset, width: cropSize, height: cropSize)
            } else {
                // CGImage is landscape, matches UIImage
                // Crop horizontally in CGImage
                cropRect = CGRect(x: offset, y: 0, width: cropSize, height: cropSize)
            }
            
            print("📐 Landscape crop: size=\(cropSize), CGImage=(\(cgWidth), \(cgHeight)), UIImage.size=\(imageSize)")
        }
        
        // Ensure crop rect is valid and within CGImage bounds
        let imageRect = CGRect(origin: .zero, size: CGSize(width: cgWidth, height: cgHeight))
        let validCropRect = cropRect.intersection(imageRect)
        
        guard !validCropRect.isEmpty,
              validCropRect.width > 0,
              validCropRect.height > 0,
              abs(validCropRect.width - validCropRect.height) < 1.0, // Should be square
              let croppedCGImage = cgImage.cropping(to: validCropRect) else {
            print("⚠️ Crop failed, using fallback. CropRect: \(cropRect), Valid: \(validCropRect)")
            return cropToSquareFallback(image: image)
        }
        
        // Preserve the original image orientation so it displays correctly (portrait)
        // The CGImage might be stored in landscape, but UIImage orientation makes it display as portrait
        return UIImage(cgImage: croppedCGImage, scale: image.scale, orientation: image.imageOrientation)
    }
    
    private func cropToSquareFallback(image: UIImage) -> UIImage {
        // Fallback: centered square crop
        let imageSize = image.size
        let minDim = min(imageSize.width, imageSize.height)
        let cropRect = CGRect(
            x: (imageSize.width - minDim) / 2,
            y: (imageSize.height - minDim) / 2,
            width: minDim,
            height: minDim
        )
        
        guard let cgImage = image.cgImage?.cropping(to: cropRect) else {
            return image
        }
        
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
    }
}
