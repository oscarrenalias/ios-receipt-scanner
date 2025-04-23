# Receipt Scanner App

A SwiftUI app for scanning, processing, and organizing receipts.

Features:

- Scan receipts using the device camera
- Import images from the photo library
- Image processing tools (brightness, contrast, sharpness, black & white)
- OCR (Optical Character Recognition) to extract text from receipts
- Save processed images to the photo library

## Why?

My favourite app for scanning documents was Microsoft Office Lens, but as it's part of the Microsoft suite of apps/products, it is now centrally managed by my company's IT organization and current infosec policies don't allow basic things such as saving anywhere else but our corporate OneDrive, so the app is now totally useless to me for personal use.

In addition to that, every decent document scanning app in the App Store is full of features I don't need, requires a yearly subscription (really??) or worse, both. I figured that this might as well be the time I get into iOS development.

## Vibe Coding

I also used this as an opportunity to test drive [Copilot Agent in VS Code](https://code.visualstudio.com/docs/copilot/chat/chat-agent-mode), which was released a couple of weeks before I started work on this app. To be clear, approximately 98% of this app's code has been written by VS Code's Copilot Agent so, yes – I [vibe coded](https://en.wikipedia.org/wiki/Vibe_coding) it.

My responsibilities during development consisted of:

- Craft the right prompts to request features, fixes and experiments; Copilot Agent was surprisingly good at understanding short prompts when starting but more detailed prompts usually got me closer to what I had in mind
- Break down the target set of features into smaller incremental deliveries that can be sequentially implemented; otherwise, the agent will be happy to boil the ocean for you but I did not trust that the agent could deliver the final set of features in one shot 
- Ensure that the agent generates decent code, ensure it follows basic software engineering practices such as DRY, proper encapsulation, and trigger regular refactorings to keep code simple and maintainable
- Manage progress, revert to a previous known working state when Copilot went off track; it did not happen too many times, thankfully, but it's a bit annoying that agents can't still detect that they're working on a new feature and suggest that a new git branch should be created, or create "checkpoints" along the way with git commit so that it's easy to revert to a last known working state

Overall, I am calling the experiment a success. While I don't know enough Swift and iOS development practices to assess the quality of the code and implementation, the results look good enough to me and the app fulfills its functional purpose. I am also quite happy with how efficient (and fast!) Copilot Agent with GPT-4.1 is for coding, at least for basic apps like this one where it's all boring logic using a language and a framework for which there's a massive corpus of training material for the coding model, so it should know very well what to do for 100% of the prompts.

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
- Vision framework is used for OCR functionality and automated edge detection

## Requesting Permissions at Runtime

The app will automatically request the necessary permissions when they are first needed:
- Camera access will be requested when the user tries to scan a receipt
- Photo library access will be requested when importing or saving images

## Troubleshooting

If permissions are denied:
1. Go to the device Settings
2. Find the Receipt Scanner app
3. Enable the required permissions (Camera, Photos)
