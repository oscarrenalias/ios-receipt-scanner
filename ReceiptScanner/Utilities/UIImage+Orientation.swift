// Utilities/UIImage+Orientation.swift
import UIKit

extension UIImage {
    func normalizedToUpOrientation() -> UIImage {
        if imageOrientation == .up {
            return self
        }
        guard let cgImage = self.cgImage else { return self }
        let width = size.width
        let height = size.height
        var transform = CGAffineTransform.identity
        
        switch imageOrientation {
        case .down, .downMirrored:
            transform = transform.translatedBy(x: width, y: height)
            transform = transform.rotated(by: .pi)
        case .left, .leftMirrored:
            transform = transform.translatedBy(x: width, y: 0)
            transform = transform.rotated(by: .pi / 2)
        case .right, .rightMirrored:
            transform = transform.translatedBy(x: 0, y: height)
            transform = transform.rotated(by: -.pi / 2)
        default:
            break
        }
        
        switch imageOrientation {
        case .upMirrored, .downMirrored:
            transform = transform.translatedBy(x: width, y: 0)
            transform = transform.scaledBy(x: -1, y: 1)
        case .leftMirrored, .rightMirrored:
            transform = transform.translatedBy(x: height, y: 0)
            transform.scaledBy(x: -1, y: 1)
        default:
            break
        }
        
        guard let colorSpace = cgImage.colorSpace,
              let context = CGContext(
                data: nil,
                width: Int(width),
                height: Int(height),
                bitsPerComponent: cgImage.bitsPerComponent,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: cgImage.bitmapInfo.rawValue
              ) else {
            return self
        }
        context.concatenate(transform)
        let drawRect: CGRect
        switch imageOrientation {
        case .left, .leftMirrored, .right, .rightMirrored:
            drawRect = CGRect(x: 0, y: 0, width: height, height: width)
        default:
            drawRect = CGRect(x: 0, y: 0, width: width, height: height)
        }
        context.draw(cgImage, in: drawRect)
        guard let newCGImage = context.makeImage() else { return self }
        return UIImage(cgImage: newCGImage, scale: scale, orientation: .up)
    }
}