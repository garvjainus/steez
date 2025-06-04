# Steez - Fashion Video & Image Analysis App

Steez is an iOS app that helps users discover and track fashion items from videos and images. It uses computer vision to detect clothing items and finds the best prices across multiple retailers.

## Features

- Share extension for importing from social media apps
- Video and image analysis for clothing detection
- Product matching and price comparison
- Digital wardrobe organization
- Price drop notifications
- Multi-device sync

## Requirements

- iOS 15.0+
- Xcode 13.0+
- Swift 5.5+
- CocoaPods

## Setup

1. Clone the repository
2. Install dependencies:
   ```bash
   pod install
   ```
3. Open `Steez.xcworkspace` in Xcode
4. Configure your development team and bundle identifier
5. Update the API endpoints in `NetworkService.swift`
6. Build and run the project

## Project Structure

- `Sources/App`: Main app entry point and app state
- `Sources/Core`: Data models and networking
- `Sources/Features`: Main app features
- `Sources/UI`: Reusable UI components
- `Sources/Utils`: Utility functions and extensions
- `Sources/ShareExtension`: Share extension implementation

## Architecture

The app follows MVVM-C architecture pattern:
- Models: Data structures and business logic
- Views: SwiftUI views and view models
- ViewModels: Business logic and state management
- Coordinators: Navigation and flow control

## Development

1. Create a new branch for your feature
2. Make your changes
3. Write tests if applicable
4. Submit a pull request

## License

This project is proprietary and confidential.

## Contact

For support or inquiries, please contact the development team. 