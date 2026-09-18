# Changelog

All notable changes are documented here, following
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and
[Semantic Versioning](https://semver.org/).

## Unreleased

### Added

- Station metadata on `/stations/{stationId}` through `observationStation(identifier:)`, with a
  reusable request and a typed endpoint.
- The observation a station made at an exact instant on `/stations/{stationId}/observations/{time}`
  through `observation(stationIdentifier:timestamp:)`, with a reusable request and a typed endpoint.
  The service answers an instant with no matching observation with `404` problem details.
- `ObservationStation` decodes the provider, sub-provider, forecast, county, and fire weather zone
  links, and the distance and bearing that location-relative station lists include.
- Active alerts for a marine region on `/alerts/active/region/{region}` through `MarineRegionCode` or
  a String-backed enum, with a client method, reusable request, typed endpoint, and the existing
  active-alert page and feature sequences.
- Active alert counts on `/alerts/active/count` as `ActiveAlertCount`, with total, land, and marine
  counts and breakdowns keyed by area code, marine region code, and zone identifier.
- The recognized alert event names on `/alerts/types` as `AlertTypes`.
- `MediaType.jsonLD` for endpoints the service offers only as JSON-LD.
- `AreaCode` and `MarineRegionCode` conform to `CodingKeyRepresentable`, so they key JSON objects.
- Alert history on `/alerts` through validated `AlertQuery` values combining the active-alert
  filter with a time window, page size, and initial cursor, with one-page methods, reusable
  requests, typed endpoints, and lazy `AlertPageSequence` and `AlertSequence` traversal.
- Observation history on `/stations/{stationId}/observations` through validated `ObservationQuery`
  values naming a station, time window, optional page size, and initial cursor, with one-page
  methods, reusable requests, typed endpoints, and lazy `ObservationPageSequence` and
  `ObservationSequence` traversal.
- Lazy active-alert page and feature sequences for existing filters and specialized requests, preserving
  one-page async methods, canonical redirect validation, and GeoJSON feature metadata.
- Validated observation-station queries with identifiers, state codes, page limits, and initial cursors.
- Lazy station page and feature sequences with reusable requests, independent iterators, exact
  continuation links, cancellation checks, and typed pagination errors before invalid pages are yielded.
- Portable pagination metadata and continuation validation for custom networking stacks.

### Changed

- Document the station directory as the pagination reference, including request-based page and item
  traversal, early termination, cancellation, partial-result failures, and changing-data semantics.

## [0.1.0]

### Added

- Current observations from an explicit station or the first service-listed station for a coordinate.
- Twelve-hour and hourly forecasts that follow the point's links, with explicit US/SI units and
  quantitative-value feature flags.
- Active alerts by coordinate, area, zone, and the supported CAP filters, plus individual alerts.
- Portable forecast and CAP models with nullable readings and dates, unknown response codes, and
  recorded fixtures for every supported endpoint.
- Bounded point caching with an injected clock, expiry, least-recently-used eviction, clearing,
  and opt-out. Client copies share the cache.
- WMO-to-Foundation measurement conversion and percentage fractions for display.
- Three equivalent access levels: everyday `NWSClient` methods, reusable and inspectable
  `WeatherRequest<Response>` values, and transport-independent `Endpoint<Response>` values.
- Validated coordinates, origin-checked links, bounded same-origin redirects, cancellation checks,
  and typed NWS problem-detail and transport errors.
- Apple URLSession integration and an optional `HTTPPortable` trait for Linux and Android.
- DocC catalogs for both products, README examples, and an iOS demo with observations, forecasts,
  alerts, and shared measurement formatting.
- Fixture-backed Swift Testing coverage, Linux tests under both trait sets, Android and iOS CI,
  strict lint, and documentation checks that fail on warnings.

### Changed

- Rename the package from `swift-nws` to `swift-noaa`, retaining `SwiftNWS` and `SwiftNWSModels`.
- Replace prerelease raw-coordinate overloads with `WeatherCoordinate` and `ObservationSource`.
- Replace provider-enumerated alert, forecast, and measurement strings with forward-compatible
  typed code values, including direct interoperability with consumer-defined String-backed enums.
- Add named state, territory, marine-area, and marine-region codes for alert queries while retaining
  unknown values and keeping zone identifiers and event vocabulary open.
- Keep station ordering, freshness assessment, fallback, pagination, and retries under consumer
  control; no provider guarantee is inferred.

### Fixed

- Keep the demo project compatible with Xcode 26 and document only the package's own products in CI.
- Explicitly mark the cancellation tests' unsafe task access for strict memory-safety checking.
- Reject invalid coordinates before rounding, and encode provider identifiers as path segments.
- Reject linked or redirected URLs outside the HTTPS API origin, with credentials, or with fragments.
- Preserve millisecond precision when encoding forecast and alert timestamps.
