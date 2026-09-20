# NWS feature set for swift-noaa 0.1.0 and 1.0.0

This document names what each release must contain. It describes scope, not design: types, names,
and signatures are settled when each piece is built, against the live OpenAPI spec at
<https://api.weather.gov/openapi.json>, which is the source of truth for every endpoint and field.

## Built today

The 0.1.0 implementation includes observations, linked twelve-hour and hourly forecasts,
bounded point caching, active-alert filters and canonical area, marine region, and zone endpoints,
individual alerts, active alert counts, the recognized alert event types, station metadata, the
observation at an exact instant, raw forecast grid data with every layer and parsed valid times, the
stations listed for a coordinate's grid cell as one page, and WMO measurement conversion. The station directory, active alerts, alert history, and observation
history provide lazy page and item sequences while preserving single-page endpoint and request
execution. Every HTTP operation has an
endpoint, reusable request, and client surface. Recorded fixtures, tests, both DocC catalogs, and the
demo cover these features.

Since 0.1.0, the zone phase is complete. All six probed zone routes are built: the directory
(`/zones` and `/zones/{type}`), one zone (`/zones/{type}/{zoneId}`), a zone's text forecast
(`/zones/{type}/{zoneId}/forecast`), and a forecast zone's observations and stations
(`/zones/forecast/{zoneId}/observations` and `/zones/forecast/{zoneId}/stations`), each at the
endpoint, request, and client levels, with a feature's GeoJSON geometry retained as raw JSON.

Every one of them answers one response, and that is a limitation rather than a completeness claim.
The directory declares no cursor. The zone observation route's continuation link names one station's
observation history, which drops the zone's other stations. The zone station route's declared limit
and cursor made no difference to the recorded responses, and its continuation link names the same
stations again at a later offset before leading to empty pages. The client follows neither link and
sends no cursor for either route, so there are no zone sequences. Zone forecast periods are text
only. Nothing here is a claim about other zone routes the service may offer.

The glossary is built too. `/glossary` is available at the endpoint, request, and client levels, as
JSON-LD, the only representation the service offers for it. The route documents no page size and no
cursor, so the endpoint sends neither and there are no glossary sequences; that describes the request
rather than the size of the answer. Entries decode as a required array in service order, because the
service repeats terms, and definitions keep the markup, character entities, and line endings the
service sent. Nothing renders, escapes, indexes, matches, or caches them.

Release validation runs locally before publication. The Android and hosted CI lanes must pass
on the pushed release commit before approving the 0.1.0 tag. Tagging and pushing require owner approval.

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
- The `units` query (`us` or `si`) as an explicit, extensible code value.
- The `Feature-Flags` header as explicit, extensible code values, starting with the two the forecast
  accepts, `forecast_temperature_qv` and `forecast_wind_speed_qv`. Consumers can pass their own
  `String`-backed enums. The decoded shape follows the flags a request sends, so turning a flag on never
  produces a decoding surprise.
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
  zone, region, event, status, message type, severity, urgency, certainty). Enumerated area and marine
  region inputs are extensible code values; zone identifiers and event names remain strings.
- `/alerts/active/zone/{zoneId}`, `/alerts/active/area/{area}`, and `/alerts/{id}`. Consumers can pass
  their own `String`-backed area enums at the client, reusable-request, and endpoint levels.
- An alert model covering the CAP fields the API returns, including `event`, `headline`,
  `description`, `instruction`, `severity`, `certainty`, `urgency`, `status`, `messageType`,
  `category`, `response`, `scope`, `areaDesc`, `affectedZones`, `sent`, `effective`, `onset`,
  `expires`, and `ends`. Enumerated values decode an unknown value without failing, because the API
  adds values without a version change.
- The 301 answers some alert queries give on the way to a canonical URL, followed and tested.
- A client convenience for the active alerts at a coordinate.
- GeoJSON only; the CAP XML and Atom media types wait for 1.0.0.

### Units

- A mapping from the WMO unit identifiers the API reports (`wmoUnit:degC`, `wmoUnit:km_h-1`,
  `wmoUnit:percent`, `wmoUnit:Pa`, `wmoUnit:m`, `wmoUnit:degree_(angle)`, and the rest seen in
  recorded responses) to something a consumer can convert and format, so an app does not rebuild the
  table the demo carries today. WMO identifiers remain strings because the schema does not enumerate
  them; enumerated quality-control codes use extensible code values. Where the mapping lives is settled
  with the portability rule in mind: `SwiftNWSModels` may not need full Foundation.

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
  `/gridpoints/{wfo}/{x},{y}/stations`. Built. The grid station list is one page: its
  `pagination.next` names every station for the grid again at a later offset and leads only to empty
  pages, so it does not continue the list and is never followed.
- **Stations:** `/stations` and `/stations/{stationId}`, observation history
  (`/stations/{stationId}/observations` with `start`, `end`, and `limit`), and
  `/stations/{stationId}/observations/{time}`. Observation history ships with single-page endpoint
  and request access plus page and item sequences in its first vertical slice.
- **Zones:** built. The directory across every type or for one type, one zone's properties, a zone's
  text forecast, and a forecast zone's observations and stations, with the direct endpoints
  retaining the feature's geometry. Each of the six routes answers one response: the directory
  declares no cursor, and the observation and station continuation links lead to one station's
  history and to repeated then empty pages, so neither is followed. The station route's declared
  limit and cursor are not offered, because the recorded responses ignored them.
- **Offices:** `/offices/{officeId}`, headlines, and briefings.
- **Alerts, complete:** alert history on `/alerts` with its time and status filters,
  `/alerts/active/count`, `/alerts/active/region/{region}`, and `/alerts/types`. Alert history ships
  with single-page endpoint and request access plus page and item sequences in its first vertical
  slice.
- **Products:** `/products`, product types and locations, the latest product for a type and
  location, and a single product.
- **Glossary:** `/glossary`. Built, as JSON-LD at all three access levels. The route documents no
  page size and no cursor, so none is sent and the list is one response. Entries are an array in
  service order because terms repeat, and definitions keep the service's markup, character entities,
  and line endings unchanged.
- **Pagination:** verified cursor-based collections follow `pagination.next` through lazy page and
  item sequences while retaining single-page access. Products, zones, and other lists known only to
  accept `limit` remain outside this claim until their provider continuation behavior is verified.
  Grid station lists are one page, because their continuation link is verified not to continue them.
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
