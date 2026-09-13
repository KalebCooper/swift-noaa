# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project adheres to
[Semantic Versioning](https://semver.org/).

## Unreleased

### Added

- `SwiftNWS` re-exports swifty-networking's `HTTPCore`, so `TransportError` and `Transport` are
  usable, members included, from a file that imports only `SwiftNWS`.
- `NWSClient.latestObservation(latitude:longitude:)`, the latest observation from the station
  nearest a location, looked up through the location's point and its station list.
- `NWSClient`, which sends an `Endpoint` with the configured `User-Agent` and the endpoint's media
  type and decodes the response. It is created over a `URLSession` on Apple platforms, or over any
  swifty-networking transport.
- `NWSError`, the one error `NWSClient` throws: problem details the API answered with, a transport
  failure, a link outside the API, or a point with no observation station.
- `Endpoint`, a request described as a path and a media type together with the type its response
  decodes as, with `point(latitude:longitude:)`, `observationStations(near:)`,
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
