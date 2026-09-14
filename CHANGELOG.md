# Changelog

All notable changes are documented here, following
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and
[Semantic Versioning](https://semver.org/).

## Unreleased

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
- Keep station ordering, freshness assessment, fallback, pagination, and retries under consumer
  control; no provider guarantee is inferred.

### Fixed

- Keep the demo project compatible with Xcode 26 and document only the package's own products in CI.
- Explicitly mark the cancellation tests' unsafe task access for strict memory-safety checking.
- Reject invalid coordinates before rounding, and encode provider identifiers as path segments.
- Reject linked or redirected URLs outside the HTTPS API origin, with credentials, or with fragments.
- Preserve millisecond precision when encoding forecast and alert timestamps.
