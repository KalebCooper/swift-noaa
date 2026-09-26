# ``SwiftNOAATidesModels``

Portable CO-OPS station and tide models with request descriptions, without networking dependencies.

## Overview

Use ``CoastalStationQuery`` to select a station directory and ``CoastalStationIdentifier`` to
select a station explicitly. ``TidesEndpoint`` describes a single JSON request, and
``TidesRequest`` describes the useful result. Both are immutable, Hashable, Sendable values.

```swift
let query = try CoastalStationQuery(type: .tidePredictions)
let request = TidesRequest.stations(matching: query)
let identifier = try CoastalStationIdentifier("9414290")
let detail = TidesRequest.station(identifier: identifier)
```

Directory and detail endpoints both decode ``CoastalStations`` using an ordinary JSONDecoder.
A useful detail request unwraps exactly one matching station; missing, plural, mismatched, or
malformed responses are errors. Names, provider order, empty strings, unknown kinds, capability
indicators, and optional resource links retain the provider representation. No resource is fetched
automatically. Time zone labels and offsets are metadata, not IANA zones.

## Predicted high and low tides

```swift
let range = try TidesDateRange(
  begin: TidesTimestamp("2026-09-26 00:00").date,
  end: TidesTimestamp("2026-09-27 23:59").date
)
let query = try HighLowTideQuery(
  datum: .meanLowerLowWater, range: range,
  stationIdentifier: CoastalStationIdentifier("9414290"), units: .metric
)
let request = TidesRequest.highLowTides(matching: query)
```

The useful result keeps events with `requestedQuery`. This context is requested, not echoed by
NOAA. Direct endpoint responses decode independently with an ordinary JSONDecoder and no userInfo.
Timestamps are strict GMT minutes; custom date-decoding strategies do not change their interpretation.
Both range bounds are inclusive. The high/low window is limited to ten Gregorian calendar years,
including leap-day handling; no date rounding, splitting, interpolation, or extrema calculation occurs.
Metric heights are meters and English heights are feet, relative to the explicitly requested datum.
Numeric strings retain their exact spelling; missing or malformed required values fail decoding.

Subordinate tide stations require MLLW and support high/low predictions only. The client performs no
capability preflight or station substitution. A provider refusal for no data remains an error,
including at HTTP 200, and differs from a successfully decoded empty event array.

## Sampled tides and datum metadata

```swift
let samples = try TidePredictionQuery(
  datum: .meanLowerLowWater, interval: .hourly, range: range,
  stationIdentifier: CoastalStationIdentifier("9414290"), units: .metric
)
let sampleRequest = TidesRequest.tidePredictions(matching: samples)
let datumRequest = try TidesRequest.datums(
  stationIdentifier: CoastalStationIdentifier("9414290"), units: .metric
)
```

Sampled predictions have their own query, wire response and contextual result. Supported cadences
are 1, 5, 6, 10, 15, 30 and 60 minutes, with a maximum of one Gregorian calendar year. Values remain
reported points; the package does not interpolate a curve or infer high/low events. Subordinate
stations reject sampled requests through the provider error path, without a reference-station fallback.

The datum table retains named entries, descriptions, numeric values, epoch, reported units, analysis
periods and disclaimers. A datum table is not permission to convert arbitrary heights. Individual
entry descriptions can qualify units, such as hours for time intervals. Metadata dates and times
remain provider text, without assuming GMT from the separate Data API query contract.

## Six-minute measured water levels

Use `WaterLevelQuery` with `waterLevels(matching:)`, `TidesRequest.waterLevels(matching:)`, or
`TidesEndpoint.waterLevels(matching:)`. These request `product=water_level` with explicit datum,
units and inclusive GMT minute bounds, limited to one Gregorian calendar month. There is no latest
selector, station substitution or automatic date-window splitting.

`WaterLevelResponse` retains provider station metadata and observations; `WaterLevels` adds the
original `requestedQuery` separately. Heights and sigma preserve numeric text. An empty numeric
string has no value, while malformed nonempty text and null required fields fail decoding. Missing
time steps remain absent. Quality is the provider's open `p`/`v` code, never inferred from age.

Raw flags keep their provider order. The first preliminary flag is an outlier count; the first
verified flag indicates an inferred value. The remaining fields describe flat, rate and level-limit
checks. The package does not infer flood danger, subtract predictions or fill gaps. Current products are separate operations and are not yet implemented.

## Verified hourly heights

`HourlyWaterLevelQuery` selects the separate `hourly_height` product, with explicit datum, units,
station and inclusive GMT bounds no longer than one Gregorian calendar year. Use
`hourlyWaterLevels(matching:)` at the client, request or endpoint level. This is not an interval
option on the six-minute water-level product.

`HourlyWaterLevel` retains height, sigma and raw flags. Its two flag positions indicate an inferred
value and an exceeded expected level limit. There is no echoed quality code: verification is part
of the provider product definition. `HourlyWaterLevels` keeps provider metadata and observations
alongside the original requested query. Unknown flags and empty numeric text remain observable;
missing time steps stay absent. Observed high/low levels and daily/monthly means are unsupported.

## Topics

### Stations

- ``CoastalStation``
- ``CoastalStationIdentifier``
- ``CoastalStationKind``
- ``CoastalStationQuery``
- ``CoastalStations``
- ``CoastalStationType``
- ``CoastalResource``

### Requests and errors

- ``TidesEndpoint``
- ``TidesProviderError``
- ``TidesQueryError``
- ``TidesRequest``

### High and low tides

- ``HighLowTide``
- ``HighLowTideQuery``
- ``HighLowTideResponse``
- ``HighLowTides``
- ``TideDatum``
- ``TideEventKind``
- ``TidesDateRange``
- ``TidesNumericValue``
- ``TidesTimestamp``
- ``TidesUnits``

### Sampled tides and datums

- ``CoastalDatum``
- ``CoastalDatums``
- ``TidePrediction``
- ``TidePredictionInterval``
- ``TidePredictionQuery``
- ``TidePredictionResponse``
- ``TidePredictions``

### Measured water levels

- ``CoastalDataMetadata``
- ``TidesMeasurementValue``
- ``WaterLevel``
- ``WaterLevelQuality``
- ``WaterLevelQuery``
- ``WaterLevelResponse``
- ``WaterLevels``

### Verified hourly heights

- ``HourlyWaterLevel``
- ``HourlyWaterLevelQuery``
- ``HourlyWaterLevelResponse``
- ``HourlyWaterLevels``

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

### Measured currents

- ``CurrentBin``
- ``CurrentBins``
- ``CurrentBinSelection``
- ``CurrentObservation``
- ``CurrentObservationQuery``
- ``CurrentObservationResponse``
- ``CurrentObservations``

## Current predictions

`currentEvents(matching:)` returns max/slack events from `CurrentEventQuery`. Events always request
major-axis velocity, retain signs and mean flood/ebb directions, and allow one calendar year.
A slack event can have nonzero velocity. `currentPredictions(matching:)` uses `CurrentPredictionQuery`
with a supported cadence (1, 6, 10, 30, or 60 minutes), a requested velocity mode, and at most one
calendar month. Both require an explicit positive bin or `.providerDefault`; predictions default
to the bin nearest the surface when NOAA supports that choice.

```swift
let query = try CurrentPredictionQuery(
  bin: .explicit(14), interval: .hourly, mode: .speedAndDirection, range: window,
  stationIdentifier: CoastalStationIdentifier("EPT0003"), units: .metric)
let samples = try await tides.currentPredictions(matching: query)
let request = TidesRequest.currentPredictions(matching: query)
let reusable = try await tides.value(for: request)
let wire = try await tides.send(.currentPredictions(matching: query))
```

Each sample's `CurrentVelocity` describes the **actual** major-axis or speed/direction fields.
NOAA can return major-axis data for a speed/direction request; the requested mode remains in
`requestedQuery` and never overrides those fields. Provider-reported units remain separate text.
Depth retains numeric strings or explicit null. Nothing converts velocity representations or units.

NOAA documents max/slack-only support for subordinate stations. If a sampled request receives events,
it fails decoding instead of relabeling events as samples. Provider refusals remain provider errors;
there is no automatic preflight, station substitution, alternate request, or interpolation.

### Current prediction types

- ``CurrentEvent``
- ``CurrentEventKind``
- ``CurrentEventQuery``
- ``CurrentEventResponse``
- ``CurrentEvents``
- ``CurrentPrediction``
- ``CurrentPredictionInterval``
- ``CurrentPredictionMode``
- ``CurrentPredictionQuery``
- ``CurrentPredictionResponse``
- ``CurrentPredictions``
- ``CurrentVelocity``
