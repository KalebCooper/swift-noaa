# Tides & Currents example

Open `SwiftNOAATidesDemo.xcodeproj`, select the generated app scheme and an iOS 26 or newer
simulator, then run. Close the standalone package workspace first so Xcode resolves one package copy.
Like the NWS, NPS Data, and GovInfo demos, this app uses a local `../..` package reference and the
service's SDK and models products.

Choose a station from the NOAA tide-prediction directory, select a day in GMT, and load predicted
high and low tides. The app requests meters above MLLW and displays the provider's event order.
Subordinate stations remain selectable; provider refusals are shown without substituting stations.
No API key is required. Launching the app fetches the directory; predictions load only on request.

These are predictions, not measured water levels. The app does not calculate extrema, interpolate
heights, convert datums, or provide navigation advice.

Load hourly samples to plot reported points without interpolation. Subordinate stations may refuse
sampled predictions; the provider message remains visible. No datum conversion is performed.

Measured six-minute water levels are a separate request and display, retaining provider quality
codes and flags. Missing heights are shown as missing, and absent time steps are not filled.

Verified hourly heights use `HourlyWaterLevelQuery` and `hourlyWaterLevels(matching:)` at the same
three access levels. They select the separate `hourly_height` product, retain its two raw flags,
and accept explicit GMT windows up to one calendar year. Observed high/low and daily/monthly
statistics remain unsupported.

## Current observations

Discover `.currents`, `.historicCurrents`, or `.surveyCurrents` stations, then load
`currentBins(stationIdentifier:units:)` to inspect available bins. Metadata does not establish
historical depth: deployments can change the relationship between bin and depth.

```swift
let query = try CurrentObservationQuery(
  bin: .explicit(4), range: window,
  stationIdentifier: CoastalStationIdentifier("cb0102"), units: .metric)
let measured = try await tides.currentObservations(matching: query)
let request = TidesRequest.currentObservations(matching: query)
let reusable = try await tides.value(for: request)
let wire = try await tides.send(.currentObservations(matching: query))
```

A query requires either a positive explicit bin or `.providerDefault`, and accepts up to one
calendar month of inclusive GMT minutes. Observations preserve the reported bin, direction in
degrees, and speed: metric means **centimeters per second**, English means knots. No metadata
preflight, depth inference, gap filling, or all-bin access occurs. Bin tables retain reported units,
quality flags, nullable depth/distance, and a null table when NOAA returns one. Station deployment
and retrieval times remain provider text without an assumed UTC offset. Detailed beam diagnostics
and deployment-history retrieval are not supported.
