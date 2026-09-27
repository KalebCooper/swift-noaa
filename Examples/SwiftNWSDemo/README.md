# Weather demo

A SwiftUI app showing current conditions, daily and hourly forecasts, and active alerts from the
National Weather Service. Search for an address or use your device's location.

## Run the app

1. Close the standalone `swift-noaa` package workspace in Xcode.
2. Open `SwiftNWSDemo.xcodeproj` in Xcode 26 or later.
3. Select the app scheme and an iOS 26 or later simulator or device, then run.

The app uses `SwiftNWS` and `SwiftNWSModels` from this repository through a local `../..` reference.
No API key is required. MapKit resolves addresses to coordinates, and the location button asks for
location access.

See the [weather documentation](https://kalebcooper.github.io/swift-noaa/documentation/swiftnws/)
for the client APIs, or the [package README](../../README.md) for installation and other services.
