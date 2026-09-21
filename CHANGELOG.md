# Changelog

All notable changes are documented here, following
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and
[Semantic Versioning](https://semver.org/).

## Unreleased

### Added

- Zone directory and single-zone lookups at all three access levels: `zones(matching:types:)` for
  `/zones`, `zones(matching:ofType:)` for `/zones/{type}`, and `zone(effective:identifier:type:)`
  for `/zones/{type}/{zoneId}`, each also available as a `WeatherRequest` factory and an `Endpoint`.
  The zone request factories are not optional; executing one reports an unusable type or identifier
  as `NWSError.invalidZoneType` or `NWSError.invalidZoneIdentifier` before sending. Each list is one
  request and one response: the service declares no cursor for the directory and the recorded
  responses carry no continuation, so there are no zone sequences.
- Zone forecasts through `zoneForecast(identifier:type:)`, reading
  `/zones/{type}/{zoneId}/forecast` at all three access levels and returning `ZoneForecast`: when
  the service last updated the forecast, a link to the zone, and `ZoneForecastPeriod` values that
  carry a number, a name, and forecast text and nothing else. The route accepts no units query and
  no feature flags.
- A forecast zone's observations through `observations(inForecastZone:)`, reading
  `/zones/forecast/{zoneId}/observations` with a `ZoneObservationQuery` that validates the zone
  identifier and an optional limit from 1 through 500 at construction and sends window bounds as
  whole-second ISO 8601 instants in UTC. One response carries the readings of several stations.
- A forecast zone's stations through `observationStations(inForecastZone:)`, reading
  `/zones/forecast/{zoneId}/stations`. The route declares a limit and a cursor that the recorded
  responses ignored, so neither is offered in the named factory. Passing the request to
  `observationStationPages(for:)` or `observationStations(for:)` yields its single page and
  finishes.
- Both zone lists are one response. The observation response's continuation link names one station's
  observation history, which drops the zone's other stations, and the station response's link names
  the same stations again at a later offset before leading to empty pages, so the client follows
  neither and sends no cursor for either.
- `WeatherZone`, decoding a forecast, county, fire weather, or marine zone with its office fields,
  effective and expiration dates, station links, radar station, state, and time zones, keeping an
  empty station list distinct from an absent radar station and an empty state code distinct from a
  missing one. `ZoneType` and `ZoneRegionCode` are extensible codes whose `rawValue` preserves
  values the service adds, and `ZoneQuery` carries the directory filters with a validated limit.
- `Feature.geometry`, retaining the provider's GeoJSON geometry as raw `JSONValue` when the service
  sends one, without validation, coordinate types, or spatial computation. A single zone carries a
  polygon; directory responses send `null` geometry, so a zone list is nil there even when the
  query asked for geometry. A zone forecast carries the zone's polygon as well.
- The glossary of weather terms through `glossary()`, reading `/glossary` at all three access levels
  with `WeatherRequest.glossary` and `Endpoint.glossary`. The service offers the resource only as
  JSON-LD, so the endpoint asks for `MediaType.jsonLD` and sends no query items and no feature flags,
  because the service documents no page size or cursor for it. The request wraps the endpoint, so it
  uses the plain endpoint resolution and adds no resolution case of its own.
- `WeatherGlossary` and `GlossaryEntry`, decoding the glossary as a required array of entries in
  service order. The entries are an array rather than a dictionary because the service repeats terms,
  and each entry's `definition` and `term` are required. Definitions keep the service's HTML markup,
  character entities, and carriage return line endings exactly as sent: nothing is rendered, escaped,
  stripped, normalized, indexed, or cached, and links inside a definition are not followed.
- Forecast office metadata and headlines at all three access levels: `office(identifier:)` for
  `/offices/{officeId}`, `officeHeadlines(officeIdentifier:)` for `/offices/{officeId}/headlines`,
  and `officeHeadline(identifier:officeIdentifier:)` for
  `/offices/{officeId}/headlines/{headlineId}`, each also available as a `WeatherRequest` factory
  and an `Endpoint`. The service offers these resources only as JSON-LD, so each endpoint asks for
  `MediaType.jsonLD` and sends no feature flags. The request factories are not optional; their
  `office`, `officeHeadlines`, and `officeHeadline` resolutions reject an unusable identifier before
  sending, checking the office identifier before the headline identifier.
- `WeatherOffice`, decoding an office's address, contact details, region, parent office, and
  responsible zone and approved station links in service order. Optional fields are nil only when
  the service omits them or sends `null`, so an empty fax number stays `""`.
- `OfficeHeadlines` and `OfficeHeadline`, decoding an office's headlines in service order. An empty
  list decodes as no headlines, and a body without the headline array fails to decode. A headline's
  `url` is its API identity; its `link` is editorial content that may point off the API origin and
  is never followed; its `content` is unrendered HTML kept as sent. The headline list is one
  response, because the route documents no page size or cursor.
- Office briefing metadata at all three access levels: `officeBriefing(officeIdentifier:)` for
  `/offices/{officeId}/briefing`, also available as a `WeatherRequest` factory and an `Endpoint`.
  `OfficeBriefingResponse` decodes the required `briefing` key, whose `null` value means the office
  has no current briefing. The client method and request return an optional `OfficeBriefing`, nil
  after one request with no fallback, while an unknown office's `404` stays `NWSError.problem`. The
  `officeBriefing` resolution rejects an unusable office identifier before sending. Every
  `OfficeBriefing` field is optional, its dates decode as ISO 8601, and a present `download` value
  that is not a URL fails to decode.
- A briefing's `download` link is never requested. Briefing documents
  (`/offices/{officeId}/briefing/download/latest` and
  `/offices/{officeId}/briefing/download/{briefingId}`) are not supported, weather stories are not supported, and no PDF or image is downloaded.
- The product catalogs at all three access levels: `productTypes()` for `/products/types`,
  `productLocations()` for `/products/locations`, `productLocations(for:)` for
  `/products/types/{typeId}/locations`, and `productTypes(at:)` for
  `/products/locations/{locationId}/types`, each also available as a `WeatherRequest` factory and
  an `Endpoint`. The service offers these resources only as JSON-LD, so each endpoint asks for
  `MediaType.jsonLD` and sends no query items and no feature flags, because the routes document no
  page size or cursor. The two catalogs that take no argument are endpoint properties whose
  requests use the plain endpoint resolution; the two that take a code or an identifier are
  failable endpoint factories whose `productLocations` and `productTypes` resolutions reject an
  unusable argument before sending. Every level also accepts a String-backed product code of the
  consumer's own.
- `ProductTypes` and `ProductType`, decoding a catalog's required `@graph` array in service order.
  A product type's `productCode` and `productName` are both required, and a body without the array
  fails to decode rather than producing an empty list.
- `ProductLocations`, decoding a catalog's required `locations` object as `[String: String?]`. The
  service lists most identifiers without a description, sending `null`, and an undescribed location
  is kept with a nil value rather than dropped, because its identifier is usable on the product
  routes either way. Encoding writes it back as `null`. A body without the object fails to decode.
- `ProductCode`, an extensible String-backed code naming one kind of text product, with
  `areaForecastDiscussion` (`AFD`), `publicZoneForecast` (`ZFP`), and `specialWeatherStatement`
  (`SPS`) named and every other code usable through `init(rawValue:)`, preserving the service's
  exact value.
- The catalogs name what the service issues and carry no product text. `/products`,
  `/products/{productId}`, `/products/types/{typeId}`,
  `/products/types/{typeId}/locations/{locationId}`, and that pairing's `/latest` route are not yet
  built, and plain-text product retrieval is not supported.

### Changed

- Make endpoint paths immutable and raw-path initializers failable, preserving accepted encoded text
  exactly while rejecting invalid paths and encoded traversal forms.
- Make station, alert, area, region, and zone endpoint factories failable. Area, region, and alert
  zone request factories also return optional requests; client methods reject invalid locations with
  `NWSError.invalidAlertLocation`. Station and alert execution retains its typed identifier errors.
- Validate observation-query station paths, redirect paths before URL resolution, and forecast
  reconstruction. Forecast options safely encode custom units while preserving other query fields.
- Page and feature iterators explicitly forward caller isolation through every wrapper and redirected
  page fetch. Iterators remain serial, independent traversals with typed errors.
- Add the `invalidZoneIdentifier` and `invalidZoneType` cases to `NWSError`. This is a source break
  for any consumer switching over `NWSError` exhaustively, which must handle the two new cases.
- Add the `invalidHeadlineIdentifier` and `invalidOfficeIdentifier` cases to `NWSError`. This is a
  source break for any consumer switching over `NWSError` exhaustively, which must handle the two new
  cases.
- Add the `invalidProductCode` and `invalidProductLocation` cases to `NWSError`. This is a source
  break for any consumer switching over `NWSError` exhaustively, which must handle the two new
  cases.

## [0.1.0] - 2026-09-18

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
- The observation stations near a coordinate as one page through `observationStations(near:)` and
  a reusable `WeatherRequest.observationStations(near:)` request, alongside the existing
  `Endpoint.observationStations(near:)`. Station page and feature sequences accept the request and
  yield that one page; the page's continuation link is not followed because it does not continue
  the list.
- Raw forecast grid lookups through `forecastGrid(for:)`, a reusable
  `WeatherRequest.forecastGrid(for:)` request, and `Endpoint.forecastGrid(for:)`, which follows a
  point's grid data link. Grid lookups share the point cache; grids themselves are not cached.
- `ForecastGrid`, the raw forecast grid data on `/gridpoints/{wfo}/{x},{y}`, with every
  quantitative layer keyed by an extensible `ForecastGridLayerName`, `ForecastGridLayer` and
  `ForecastGridValue` values over `ValidTimeInterval`s, typed `ForecastWeather` and `ForecastHazard`
  layers with open weather codes, and preserved unknown layers and properties.
  `ForecastGridValue.quantity(unitCode:)` pairs a value with its layer's unit.
- `ValidTimeInterval` and `ISO8601Duration`, parsing ISO 8601 start-and-duration intervals into a
  start instant, the duration's calendar components, and an exact length and end when the duration
  has no years or months. The exact text is retained, and other interval forms are rejected.
- `WeatherObservation` decodes every field of the service's observation schema: `elevation`,
  `station`, `rawMessage`, `icon`, `seaLevelPressure`, `maxTemperatureLast24Hours`,
  `minTemperatureLast24Hours`, `precipitationLastHour`, `precipitationLast3Hours`,
  `precipitationLast6Hours`, `presentWeather`, and `cloudLayers`.
- `WeatherPhenomenon` for a decoded METAR present weather group, with open
  `WeatherPhenomenonIntensity`, `WeatherPhenomenonModifier`, and `WeatherPhenomenonKind` codes.
- `CloudLayer` for a reported cloud layer's base and open `CloudLayerAmount` sky coverage code.
- `ProblemDetail.parameterErrors`, the request parameters the service rejected, such as an unknown
  marine region, with the values it accepts.
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

- Rename the package from `swift-nws` to `swift-noaa`, retaining `SwiftNWS` and `SwiftNWSModels`.
- Replace prerelease raw-coordinate overloads with `WeatherCoordinate` and `ObservationSource`.
- Replace provider-enumerated alert, forecast, and measurement strings with forward-compatible
  typed code values, including direct interoperability with consumer-defined String-backed enums.
- Add named state, territory, marine-area, and marine-region codes for alert queries while retaining
  unknown values and keeping zone identifiers and event vocabulary open.
- Keep station ordering, freshness assessment, fallback, and retries under consumer control, and make
  pagination opt-in; no provider guarantee is inferred.
- `WeatherForecast.validTimes` is a `ValidTimeInterval` rather than a `String`. Its text remains
  available as `validTimes.rawValue`.
- `WeatherObservation`'s memberwise initializer takes the new fields in alphabetical order.
- Document the station directory as the pagination reference, including request-based page and item
  traversal, early termination, cancellation, partial-result failures, and changing-data semantics.

### Fixed

- Keep the demo project compatible with Xcode 26 and document only the package's own products in CI.
- Explicitly mark the cancellation tests' unsafe task access for strict memory-safety checking.
- Reject invalid coordinates before rounding, and encode provider identifiers as path segments.
- Reject linked or redirected URLs outside the HTTPS API origin, with credentials, or with fragments.
- Preserve millisecond precision when encoding forecast and alert timestamps.
