# Decoding office data

Decode a forecast office's metadata, headlines, and briefing metadata with any networking stack.

## Overview

Four office routes decode into these models:

| Path | Endpoint | Decodes as |
|---|---|---|
| `/offices/{officeId}` | `Endpoint.office(identifier:)` | ``WeatherOffice`` |
| `/offices/{officeId}/headlines` | `Endpoint.officeHeadlines(officeIdentifier:)` | ``OfficeHeadlines`` |
| `/offices/{officeId}/headlines/{headlineId}` | `Endpoint.officeHeadline(identifier:officeIdentifier:)` | ``OfficeHeadline`` |
| `/offices/{officeId}/briefing` | `Endpoint.officeBriefing(officeIdentifier:)` | ``OfficeBriefingResponse`` |

```swift
import SwiftNWSModels

guard let endpoint = Endpoint.office(identifier: "EWX") else { return }
print(endpoint.path)             // "/offices/EWX"
print(endpoint.accept.rawValue)  // "application/ld+json"

// Send a GET to https://api.weather.gov plus endpoint.path with that Accept header and a
// User-Agent identifying your application, then:
let office = try JSONDecoder().decode(WeatherOffice.self, from: body)
print(office.name)  // "Austin/San Antonio, TX"
```

The service offers these resources only as JSON-LD, so each endpoint asks for
``MediaType/jsonLD`` and carries no query items and no feature flags. Each body decodes whole, with
no GeoJSON wrapper. Every identifier is encoded as one path segment and is not upper-cased or
otherwise normalized, and each factory returns nil for an empty identifier or one that produces an
invalid encoded path.

## Execution

`WeatherRequest.office(identifier:)`, `WeatherRequest.officeHeadlines(officeIdentifier:)`,
`WeatherRequest.officeHeadline(identifier:officeIdentifier:)`, and
`WeatherRequest.officeBriefing(officeIdentifier:)` always return a request and carry the `office`,
`officeHeadlines`, `officeHeadline`, and `officeBriefing` resolution cases:

```swift
let request = WeatherRequest.officeHeadline(
  identifier: "ab45482ca5f57ff412eb1320721d5ac9", officeIdentifier: "EWX")
if case .officeHeadline(let identifier, let officeIdentifier) = request.resolution {
  print(officeIdentifier, identifier)
}
```

The cases exist so an executor validates the identifiers before any request: it unwraps the
endpoint factory and reports an unusable identifier without sending. A headline lookup checks the
office identifier first, so the failure names which argument was unusable. After that each case is
one request. The first three return the whole body; an `officeBriefing` request returns an optional
``OfficeBriefing``, the value of the body's `briefing` key. See <doc:ExecutingRequests>.

The same endpoints decode a response model of your own, when you want less than the full body:

```swift
struct OfficeName: Decodable, Sendable {
  let id: String
  let name: String
}

if let endpoint = Endpoint<OfficeName>(accept: .jsonLD, path: "/offices/EWX") {
  let request = WeatherRequest(endpoint: endpoint)
}
```

## Offices

``WeatherOffice/id`` and ``WeatherOffice/name`` are required. Every other field is optional, and is
nil only when the service omits it or sends `null`. A value the service does send is kept as sent.
One recorded office sends its fax number as an empty string, and ``WeatherOffice/faxNumber`` keeps
`""` rather than turning it into nil, so an empty value and a missing one stay distinct.

| Property | Type | Notes |
|---|---|---|
| ``WeatherOffice/address`` | ``WeatherOffice/Address`` | Street, locality, region, and postal code, each optional and kept as sent. |
| ``WeatherOffice/approvedObservationStations`` | `[URL]` | Station links, in service order. |
| ``WeatherOffice/parentOrganization`` | `URL` | The regional headquarters the office reports to. |
| ``WeatherOffice/responsibleCounties`` | `[URL]` | County zone links, in service order. |
| ``WeatherOffice/responsibleFireZones`` | `[URL]` | Fire weather zone links, in service order. |
| ``WeatherOffice/responsibleForecastZones`` | `[URL]` | Public forecast zone links, in service order. |
| ``WeatherOffice/sameAs`` | `String` | The office's public website, outside the API origin, kept as sent. |
| ``WeatherOffice/url`` | `URL` | The office's API identity, from `@id`. |

The zone, station, and parent office fields are links to other API resources. Turn one into an
endpoint with ``Endpoint/init(accept:featureFlags:link:)-(_,[ForecastFeatureFlag],_)``, which
refuses any origin other than the HTTPS API, rather than rebuilding its path. These models follow
none of them. The website in ``WeatherOffice/sameAs`` is not an API link: it is text, kept exactly
as sent, so an empty or malformed value never fails the office to decode.

## Headlines

``OfficeHeadlines/headlines`` decodes from the body's `@graph` key and keeps the order the service
listed the headlines in. An office with nothing to say answers a present but empty array, which
decodes as no headlines. A body without a `@graph` array, or with one that is not an array of
headlines, fails to decode rather than producing an empty list, so an empty result and a missing
one stay distinct.

The headline list is one response. The route documents no page size and no cursor, so the endpoint
sends neither and there is no continuation to read. That describes the request, not a guarantee
about how many headlines come back. Nothing here sorts headlines or filters them by importance or
issuance time.

``OfficeHeadline/id`` and ``OfficeHeadline/title`` are required. Every other field is optional, and
is nil only when the service omits it or sends `null`; a recorded headline sends a `null` summary.
``OfficeHeadline/issuanceTime`` decodes as ISO 8601 independently of the decoder's date strategy,
and text that is not ISO 8601 fails to decode.

A headline carries two kinds of link:

- ``OfficeHeadline/url``, decoded from `@id`, is the headline's identity in the API. It becomes a
  validated endpoint, like any other API link.
- ``OfficeHeadline/link`` is editorial content for a reader. It may point outside the API origin,
  and the package never sends a request to it. It is text, kept exactly as sent, so an empty string
  or bare text is preserved and never fails the headline, or the list around it, to decode.

```swift
let headline = try JSONDecoder().decode(OfficeHeadline.self, from: body)
if let identity = headline.url {
  let detail = Endpoint<OfficeHeadline>(accept: .jsonLD, link: identity)  // An endpoint
}
if let editorial = headline.link {
  print(editorial)  // Text for a reader, never an endpoint
}
```

``OfficeHeadline/content`` is unrendered HTML, kept exactly as sent with its markup and percent
escapes. These models do not render, escape, strip, or sanitize it, and links inside it are text.
Decide how to present it before displaying it.

## Briefings

`/offices/{officeId}/briefing` answers with an envelope around the office's current briefing:

```json
{
  "@context": { "@version": "1.1" },
  "briefing": {
    "id": "3913ad35-9342-46fb-b8ab-5f148277426c",
    "officeId": "LWX",
    "startTime": "2026-09-18T14:40:00+00:00",
    "title": "Click to view briefing",
    "download": "https://api.weather.gov/offices/LWX/briefing/download/3913ad35-9342-46fb-b8ab-5f148277426c"
  }
}
```

``OfficeBriefingResponse`` decodes that envelope. Its `briefing` key is required, and its value is
either the briefing's metadata or `null`. An office with no current briefing answers `null`, which
decodes as a nil ``OfficeBriefingResponse/briefing``. A body without the key, or with a value that
is neither an object nor `null`, fails to decode, so no current briefing and a malformed response
stay distinct. The JSON-LD context is not kept.

Decode it with any networking stack:

```swift
guard let endpoint = Endpoint.officeBriefing(officeIdentifier: "LWX") else { return }
print(endpoint.path)  // "/offices/LWX/briefing"

// Send a GET to https://api.weather.gov plus endpoint.path with that Accept header and a
// User-Agent identifying your application, then:
let response = try JSONDecoder().decode(OfficeBriefingResponse.self, from: body)
if let briefing = response.briefing {
  print(briefing.title ?? "Untitled briefing")
} else {
  print("No current briefing")
}
```

Every field of ``OfficeBriefing`` is optional, because the route documents none of them as
required, and is nil only when the service omits it or sends `null`. A value that is present but
malformed fails to decode: a date that is not ISO 8601, a priority that is not a Boolean, or a
download link that is not a URL.

| Property | Type | Notes |
|---|---|---|
| ``OfficeBriefing/description`` | `String` | The office's description of the briefing. |
| ``OfficeBriefing/download`` | `URL` | The API link to the briefing's document. Never requested. |
| ``OfficeBriefing/endTime`` | `Date` | When the briefing stops being current, ISO 8601. |
| ``OfficeBriefing/id`` | `String` | Kept as sent, not validated as a UUID. |
| ``OfficeBriefing/officeId`` | `String` | The publishing office, such as `LWX`. |
| ``OfficeBriefing/priority`` | `Bool` | Whether the office marked the briefing a priority. |
| ``OfficeBriefing/startTime`` | `Date` | When the briefing becomes current, ISO 8601. |
| ``OfficeBriefing/title`` | `String` | The briefing's title. |
| ``OfficeBriefing/updateTime`` | `Date` | When the office last updated the briefing, ISO 8601. |

The dates decode as ISO 8601 independently of the decoder's date strategy.

``OfficeBriefing/download`` is a URL, not content. These models never request it, and the package
does not retrieve briefing documents, which are PDFs. Hand the URL to your own networking stack, a
web view, or the system browser to show the briefing.

## What is not supported

- Briefing documents, `/offices/{officeId}/briefing/download/latest` and
  `/offices/{officeId}/briefing/download/{briefingId}`, are not supported. PDF bodies have no model.
- Weather stories, `/offices/{officeId}/weatherstories` and its image download, are not supported.
- No PDF or image is ever downloaded. These models describe JSON-LD bodies only.

## Topics

### Offices

- ``OfficeBriefing``
- ``OfficeBriefingResponse``
- ``OfficeHeadline``
- ``OfficeHeadlines``
- ``WeatherOffice``
