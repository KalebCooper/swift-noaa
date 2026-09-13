# swift-nws feature set for 0.1.0 and 1.0.0

This document names what each release must contain. It describes scope, not design: types, names,
and signatures are settled when each piece is built, against the live OpenAPI spec at
<https://api.weather.gov/openapi.json>, which is the source of truth for every endpoint and field.

## Built today

- `/points/{latitude},{longitude}`, the observation stations a point links to, and
  `/stations/{stationId}/observations/latest`, as `Endpoint` values and `Codable` models.
- `NWSClient.latestObservation(latitude:longitude:)`, sending through `URLSession` on Apple
  platforms and through AsyncHTTPClient on Linux and Android under the `HTTPPortable` trait.
- `NWSError`, mapping RFC 7807 problem details into a typed error.
- An iOS demo app in `Examples/SwiftNWSDemo`.

## 0.1.0: current conditions, forecast, and active alerts for a location

The first tagged release is the smallest package a weather app can ship on: given a coordinate, it
answers "what is it like now", "what is coming", and "is anything dangerous happening", on every
platform the package claims, documented and tested in CI.

### Forecasts

- The 12-hour forecast (`/gridpoints/{wfo}/{x},{y}/forecast`) and the hourly forecast
  (`/gridpoints/{wfo}/{x},{y}/forecast/hourly`), reached by following the point's `forecast` and
  `forecastHourly` links rather than rebuilding the path.
- Models for both forecast shapes and their periods: `number`, `name`, `startTime`, `endTime`,
  `isDaytime`, `temperature`, `temperatureUnit`, `temperatureTrend`, `probabilityOfPrecipitation`,
  `windSpeed`, `windGust`, `windDirection`, `icon`, `shortForecast`, `detailedForecast`, plus
  `dewpoint` and `relativeHumidity` on hourly periods, and the forecast's `updateTime`,
  `generatedAt`, `validTimes`, and `elevation`.
- The `units` query (`us` or `si`) as an explicit option.
- The `Feature-Flags` header as explicit options, starting with the two the forecast accepts,
  `forecast_temperature_qv` and `forecast_wind_speed_qv`. The decoded shape follows the flags a
  request sends, so turning a flag on never produces a decoding surprise.
- Client conveniences for a coordinate's forecast and hourly forecast.

### Point caching

- The client remembers the point for a coordinate (rounded to the four decimal places the path
  uses), so a forecast, an hourly forecast, and current conditions for the same place cost one
  `/points` request instead of three.
- Bounded in size, guarded by `Mutex`, with expiry measured by an injected `Clock`, since the
  point-to-grid mapping is stable but not permanent.
- A way to opt out of or clear the cache.

### Active alerts

- `/alerts/active` filtered by point, and by the other active-alert filters the spec lists (area,
  zone, region, event, status, message type, severity, urgency, certainty).
- `/alerts/active/zone/{zoneId}`, `/alerts/active/area/{area}`, and `/alerts/{id}`.
- An alert model covering the CAP fields the API returns, including `event`, `headline`,
  `description`, `instruction`, `severity`, `certainty`, `urgency`, `status`, `messageType`,
  `category`, `response`, `areaDesc`, `affectedZones`, `sent`, `effective`, `onset`, `expires`, and
  `ends`. Enumerations decode an unknown value without failing, because the API adds values without
  a version change.
- The 301 answers some alert queries give on the way to a canonical URL, followed and tested.
- A client convenience for the active alerts at a coordinate.
- GeoJSON only; the CAP XML and Atom media types wait for 1.0.0.

### Units

- A mapping from the WMO unit codes the API reports (`wmoUnit:degC`, `wmoUnit:km_h-1`,
  `wmoUnit:percent`, `wmoUnit:Pa`, `wmoUnit:m`, `wmoUnit:degree_(angle)`, and the rest seen in
  recorded responses) to something a consumer can convert and format, so an app does not rebuild the
  table the demo carries today. Where it lives is settled with the portability rule in mind:
  `SwiftNWSModels` may not need full Foundation.

### Release quality

- Fixtures recorded from the live API for every new endpoint, and decoding tests against them.
- DocC catalogs for both products, building at zero warnings, published to GitHub Pages and Swift
  Package Index.
- CI green on every lane: Linux under both trait sets, Android, the iOS simulator, lint, and docs.
- README usage for forecasts and alerts, and the demo app showing both.
- A `## [0.1.0]` section in `CHANGELOG.md` and a tag.

## 1.0.0: a stable, complete client for the core API

1.0.0 is the promise that the public API will not break until 2.0.0. It needs the rest of the core
endpoint groups, the plumbing lists and history require, and a final pass on every public name.

- **Points:** `/points/{latitude},{longitude}/stations` and `/points/{latitude},{longitude}/radio`.
- **Grid data:** raw `/gridpoints/{wfo}/{x},{y}` with every layer, each value carrying its ISO 8601
  `validTime` interval (`2026-09-13T12:00:00+00:00/PT3H`) parsed into a start and a duration, plus
  `/gridpoints/{wfo}/{x},{y}/stations`.
- **Stations:** `/stations` and `/stations/{stationId}`, observation history
  (`/stations/{stationId}/observations` with `start`, `end`, and `limit`), and
  `/stations/{stationId}/observations/{time}`.
- **Zones:** `/zones`, `/zones/{type}`, `/zones/{type}/{zoneId}`, the zone forecast, and a forecast
  zone's observations and stations.
- **Offices:** `/offices/{officeId}`, headlines, and briefings.
- **Alerts, complete:** alert history on `/alerts` with its time and status filters,
  `/alerts/active/count`, `/alerts/active/region/{region}`, and `/alerts/types`.
- **Products:** `/products`, product types and locations, the latest product for a type and
  location, and a single product.
- **Glossary:** `/glossary`.
- **Pagination:** `cursor` and `limit`, following `pagination.next`, exposed as a way to walk pages
  that stops on the API's last page or a consumer's limit.
- **Media types:** CAP XML and Atom for alerts, and `application/pdf` for office briefings, each
  either supported or listed as not supported. No endpoint is left in an unstated state.
- **Out of scope, stated as such:** `/radar`, `/aviation` (SIGMETs, center weather advisories,
  TAFs), `/icons`, `/thumbnails`, and `/radio`, unless a consumer need appears before 1.0.0.
- **Feature flags:** every flag the spec lists is modeled for every endpoint that accepts it.
- **Resilience:** a stated retry policy for the 500 and 503 answers the API gives under load, with
  backoff timed by an injected `Clock`, and a stated position on HTTP caching headers.
- **Forward compatibility:** every enumeration tolerates unknown values, every `QuantitativeValue`
  tolerates a `null` value, and every model decodes the fixtures recorded for it.
- **Spec drift:** a script, run by hand and never by the test suite, that compares the covered paths
  and schemas with the live OpenAPI spec and lists what changed.
- **Test support for consumers:** a `SwiftNWSTesting` product with a client over a mock transport
  and the recorded fixtures, so an app can test its weather code without the network.
- **API review:** every public name checked against the Swift API Design Guidelines, and no public
  type named after an Apple module a consumer is likely to import alongside it.
- **Documentation:** DocC articles on getting started, the `User-Agent` requirement, points and
  grids, units, feature flags, errors, and Linux and Android setup.
- **Platforms:** CI building on macOS, tvOS, watchOS, and visionOS as well as testing on iOS,
  Linux, and Android.
- **Project:** a `SECURITY.md`, a deprecation policy, and a Semantic Versioning commitment in the
  README.
