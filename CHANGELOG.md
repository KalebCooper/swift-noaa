# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project adheres to
[Semantic Versioning](https://semver.org/).

## Unreleased

### Added

- Active alerts by coordinate, area, zone, and typed filters, plus single-alert lookups.
- Portable CAP models that preserve unknown codes and optional fields, with recorded alert fixtures.
- Bounded same-origin redirects with cancellation checks and alert sections in the demo.

- Bounded point caching with injected-clock expiry, least-recently-used eviction, opt-out, and clearing.

- Twelve-hour and hourly forecasts through client methods, reusable requests, and linked endpoints.
- Forecast periods, explicit units and feature flags, preserving legacy values and quantities.
- Recorded forecast fixtures, documentation, and forecast sections in the iOS demo.

- `WeatherCoordinate`, with typed validation errors and four-decimal normalization.
- `ObservationSource` and `WeatherRequest<Response>` for reusable, inspectable lookups, named
  factory extensions, and custom single-HTTP endpoints with consumer-defined response models.
- `NWSClient.value(for:)` and the Apple-platform `NWSClient(userAgent:)` initializer.
- DocC catalogs for both products, covering current conditions, request reuse, and custom execution.

- `SwiftNWS` re-exports swifty-networking's `HTTPCore`, so `TransportError` and `Transport` are
  usable, members included, from a file that imports only `SwiftNWS`.
- `NWSClient.latestObservation(from:)`, the latest observation from an explicit station or the
  first station listed for a coordinate, delegating to the typed request execution path.
- `NWSClient`, which sends an `Endpoint` with the configured `User-Agent` and the endpoint's media
  type and decodes the response. It is created over a `URLSession` on Apple platforms, or over any
  swifty-networking transport.
- `NWSError`, the one error `NWSClient` throws: problem details the API answered with, a transport
  failure, a disallowed service link, an empty station identifier, or a point with no observation station.
- `Endpoint`, a request described as a path and a media type together with the type its response
  decodes as, with `point(for:)`, `observationStations(near:)`,
  `latestObservation(stationIdentifier:)`, and `init(accept:link:)` for following a link a response
  returned.
- `Feature` and `FeatureCollection`, the GeoJSON wrappers the API's responses come in.
- `Point`, `ObservationStation`, `WeatherObservation`, `QuantitativeValue`, and `ProblemDetail`
  models. `WeatherObservation` reads and writes its timestamp as ISO 8601 itself, so it decodes the
  same under any date decoding strategy.
- `HTTPPortable`, an off-by-default trait that forwards to swifty-networking's trait of the same
  name, so `SwiftNWS` can send through AsyncHTTPClient on Linux and Android.
- `NWSConfiguration` in `SwiftNWS`, holding the `User-Agent` every request to the API must carry.
- `MediaType` in `SwiftNWSModels`, a media type the API answers with, and `MediaType.geoJSON`.
- The `SwiftNWSModels` and `SwiftNWS` products.

### Changed

- Rename the package and repository from `swift-nws` to `swift-noaa`, retaining the existing
  `SwiftNWS` and `SwiftNWSModels` products.
- Replace the unreleased raw-coordinate observation and point methods with methods accepting
  `WeatherCoordinate`. Configuration-based client initializers and `Endpoint`/`send(_:)` remain.
- Clarify that coordinate lookups use service order without a guaranteed distance ordering,
  freshness filtering, station fallback, or automatic pagination.

### Fixed

- Reject nonfinite and out-of-range coordinates before normalization can trap.
- Encode station identifiers as individual path segments.
- Validate service-link scheme, host, port, credentials, and fragments while retaining encoded
  paths and queries. Explicit HTTPS port 443 and case-insensitive origins are accepted.
- Check cancellation before every HTTP call in a lookup.
