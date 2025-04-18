# Receipt Scanner App

A SwiftUI app for scanning, processing, and organizing receipts.

## Features

- Scan receipts using the device camera
- Import images from the photo library
- Image processing tools (brightness, contrast, sharpness, black & white)
- OCR (Optical Character Recognition) to extract text from receipts
- Save processed images to the photo library

## Required Permissions

The app requires the following permissions to function properly:

- **Camera Access**: To scan receipts using the device camera
- **Photo Library Access**: To import images and save processed receipts
- **Photo Library Add-Only Access**: To save processed receipts to the photo library

## Setup Instructions

1. Open the project in Xcode
2. Make sure the Info.plist file contains the necessary usage descriptions:
   - NSCameraUsageDescription
   - NSPhotoLibraryUsageDescription
   - NSPhotoLibraryAddUsageDescription

3. Build and run the app on a device or simulator

## Implementation Notes

- The app uses SwiftUI for the user interface
- SDWebImage and SDWebImageSwiftUI are used for efficient image loading and caching
- Core Image is used for image processing operations
- Vision framework is used for OCR functionality

## Requesting Permissions at Runtime

The app will automatically request the necessary permissions when they are first needed:
- Camera access will be requested when the user tries to scan a receipt
- Photo library access will be requested when importing or saving images

## Troubleshooting

If permissions are denied:
1. Go to the device Settings
2. Find the Receipt Scanner app
3. Enable the required permissions (Camera, Photos)
