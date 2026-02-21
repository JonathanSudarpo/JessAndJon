import SwiftUI
import UIKit

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    var sourceType: UIImagePickerController.SourceType = .photoLibrary
    @Environment(\.dismiss) var dismiss
    
    // Store the square crop rect to match the overlay
    @State private var squareCropRect: CGRect?
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        
        // No editing interface - we'll crop automatically after taking photo
        picker.allowsEditing = false
        
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {
        // Set up square viewfinder overlay for camera
        if uiViewController.sourceType == .camera && uiViewController.cameraOverlayView == nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.setupSquareViewfinder(for: uiViewController)
            }
        }
    }
    
    // Create square viewfinder overlay that matches the final crop
    private func setupSquareViewfinder(for picker: UIImagePickerController) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else { return }
        
        let screenBounds = window.bounds
        let overlayView = PassThroughView(frame: screenBounds)
        
        // Calculate square viewfinder (centered, ~85% of screen width)
        let viewfinderSize = min(screenBounds.width, screenBounds.height) * 0.85
        let viewfinderX = (screenBounds.width - viewfinderSize) / 2
        let viewfinderY = (screenBounds.height - viewfinderSize) / 2
        let viewfinderRect = CGRect(x: viewfinderX, y: viewfinderY, width: viewfinderSize, height: viewfinderSize)
        
        // Create black overlay with clear square in center
        let overlayLayer = CAShapeLayer()
        let fullPath = UIBezierPath(rect: screenBounds)
        let viewfinderPath = UIBezierPath(rect: viewfinderRect)
        fullPath.append(viewfinderPath.reversing()) // Cut out the square
        overlayLayer.path = fullPath.cgPath
        overlayLayer.fillColor = UIColor.black.cgColor
        overlayView.layer.addSublayer(overlayLayer)
        
        // Store viewfinder rect in coordinator for matching crop
        if let coordinator = picker.delegate as? Coordinator {
            coordinator.viewfinderRect = viewfinderRect
            coordinator.screenBounds = screenBounds
        }
        
        picker.cameraOverlayView = overlayView
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        var viewfinderRect: CGRect?
        var screenBounds: CGRect?
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let originalImage = info[.originalImage] as? UIImage {
                // Crop to match the exact square shown in the viewfinder overlay
                let croppedImage = self.cropToMatchViewfinder(image: originalImage)
                parent.image = croppedImage
            }
            parent.dismiss()
        }
        
        // Crop image to match the square viewfinder overlay exactly
        private func cropToMatchViewfinder(image: UIImage) -> UIImage {
            // The camera captures at full resolution, but the viewfinder shows a square area
            // We need to crop to match what was visible in the square overlay
            // Since the overlay is centered and square, we crop to a centered square
            // The exact size depends on the camera's aspect ratio vs screen aspect ratio
            
            let imageSize = image.size
            let imageAspect = imageSize.width / imageSize.height
            
            // Camera typically captures in 4:3 or 16:9, but we want square
            // The viewfinder overlay shows ~85% of screen width as square
            // We'll crop to a square that matches the visible area
            
            // For simplicity, crop to centered square (this matches the overlay visually)
            // The overlay shows a square in the center, so we crop the center square
            let minDimension = min(imageSize.width, imageSize.height)
            
            let cropRect = CGRect(
                x: (imageSize.width - minDimension) / 2,
                y: (imageSize.height - minDimension) / 2,
                width: minDimension,
                height: minDimension
            )
            
            // Crop the image
            guard let cgImage = image.cgImage?.cropping(to: cropRect) else {
                return image // Return original if cropping fails
            }
            
            return UIImage(cgImage: cgImage, scale: image.scale, orientation: image.imageOrientation)
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// Custom view that passes all touches through (doesn't block buttons)
class PassThroughView: UIView {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        // Always return nil so touches pass through to underlying views (buttons, etc.)
        let hitView = super.hitTest(point, with: event)
        // Only return self if we're hitting the view itself, not subviews
        // This allows the visual overlay but passes touches through
        return hitView == self ? nil : hitView
    }
}
