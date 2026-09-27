# Tides demo

A SwiftUI app for exploring NOAA coastal stations, tide and current predictions, measured water
levels, weather and ocean observations, and station metadata. No API key is required.

## Run the app

1. Close the standalone `swift-noaa` package workspace in Xcode.
2. Open `SwiftNOAATidesDemo.xcodeproj` in Xcode 26 or later.
3. Select the app scheme and an iOS 26 or later simulator or device, then run.

The app uses the package in this repository through a local `../..` reference.

## Try it

Choose a station and a GMT day. Each product loads on explicit request; station availability varies.
Provider refusals are displayed without silently switching stations or products.

- **Predictions:** high/low tides, sampled tides, max/slack currents, and sampled current predictions.
- **Measured water levels:** latest, preliminary one-minute and six-minute levels, verified hourly
  heights, and verified observed high/low events. Observed extrema and predictions stay separate.
- **Weather and ocean observations:** air pressure, air temperature, conductivity, humidity, salinity
  and specific gravity, visibility, water temperature, and wind. Choose native six-minute or hourly
  on-hour samples; hourly selection does not average readings.
- **Metadata:** station notices, sensor status, flood thresholds, datum tables, and current bins.

Displays label product-specific units and retain raw flags and missing measurements. Omitted samples
remain gaps. Sensor status does not guarantee a recent reading. Notice markup stays unrendered.
Flood thresholds retain separate NOS/NWS/action values with requested units, but the response does
not report a datum: the demo makes no overlay, comparison, or flood classification.

Water-level queries use meters relative to mean lower low water (MLLW); no datum conversion occurs.
Current observations use centimeters per second and current predictions retain their reported
velocity form and units. Bin metadata does not establish historical deployment depth. Charts show
reported points without interpolating missing values.

See the [Tides guide](../../Sources/SwiftNOAATides/SwiftNOAATides.docc/SwiftNOAATides.md) for exact
coverage, query limits, and client examples, or the [package README](../../README.md) for installation.
