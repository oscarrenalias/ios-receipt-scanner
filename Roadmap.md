# Roadmap

## Implemented features

- Picture can be taken via camera or loaded from camera roll
- Basic image editing: light, contrast, sharpening
- Pinch to zoom
- Saving to camera roll

## Roadmap features

- Image rotation
- Pre-processing of image to apply basic edits to improve quality
- Automatic identification, when possible, of edges of the receipt/document (using Apple's Vision Framework, for example)
- Integration with iOS share dialog

### Image cropping

After selecting the crop functionality, the screen should transition to a full view of the image, and show a rectangle that can be dragged from any of its four corners to make the cropped area smaller, bigger or any rectangular shape as required. This view should support pinch to zoom (in and out), and it should keep the zoom level in mind when calculating the area of the image to crop. Additionally, it should provide two functions: first the ability to cancel the cropping and go back to the previous screen (it could be a button, or an 'x' icon on the top left, whichever is more aligned with iOS best practices), and functionality to proceed with the cropping. Again, it should be displayed in the user interface according to iOS best practices.
