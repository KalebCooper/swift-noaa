# Reading forecast offices

Retrieve a forecast office's metadata, the editorial headlines it publishes, and the metadata for
its current weather briefing.

## Overview

A forecast office is identified by a short code, such as `EWX` for Austin/San Antonio. Four
operations read what an office publishes about itself:

| Operation | Path | Returns |
|---|---|---|
| ``NWSClient/office(identifier:)`` | `/offices/{officeId}` | `WeatherOffice` |
| ``NWSClient/officeHeadlines(officeIdentifier:)`` | `/offices/{officeId}/headlines` | `OfficeHeadlines` |
| ``NWSClient/officeHeadline(identifier:officeIdentifier:)`` | `/offices/{officeId}/headlines/{headlineId}` | `OfficeHeadline` |
| ``NWSClient/officeBriefing(officeIdentifier:)`` | `/offices/{officeId}/briefing` | `OfficeBriefing?` |

```swift
import SwiftNWS
import SwiftNWSModels

let weather = NWSClient(userAgent: "(example.com, contact@example.com)")
let office = try await weather.office(identifier: "EWX")
print(office.name)  // "Austin/San Antonio, TX"

let headlines = try await weather.officeHeadlines(officeIdentifier: "EWX")
for headline in headlines.headlines {
  print(headline.title)
}
```

Each operation sends one GET asking for `application/ld+json`, the only representation the service
offers for these resources, with no query items and no feature flags. The body is decoded whole:
there is no GeoJSON wrapper to unwrap.

### Three levels of access

Each operation is available as an everyday method, as a reusable request for
``NWSClient/value(for:)``, and as the single HTTP operation for ``NWSClient/send(_:)`` or another
networking stack:

```swift
let request = WeatherRequest.officeHeadline(
  identifier: "ab45482ca5f57ff412eb1320721d5ac9", officeIdentifier: "EWX")
let reusable = try await weather.value(for: request)

if let endpoint = Endpoint.officeHeadline(
  identifier: "ab45482ca5f57ff412eb1320721d5ac9", officeIdentifier: "EWX")
{
  let direct = try await weather.send(endpoint)
}
```

The everyday methods delegate to `WeatherRequest.office(identifier:)`,
`WeatherRequest.officeHeadlines(officeIdentifier:)`,
`WeatherRequest.officeHeadline(identifier:officeIdentifier:)`, and
`WeatherRequest.officeBriefing(officeIdentifier:)`. For the first three, all three levels return the
same value. The briefing endpoint returns the whole `OfficeBriefingResponse`, while the method and
the request return its `briefing`, as described under Briefings below. The endpoint factories
return nil for an identifier they cannot encode as a path segment.

### Identifiers are checked before sending

The request factories always return a request. Executing one rejects an empty identifier, or one that
does not produce a valid encoded path, before any request is sent:

- ``NWSError/invalidOfficeIdentifier(_:)`` names an unusable office identifier.
- ``NWSError/invalidHeadlineIdentifier(_:)`` names an unusable headline identifier.

A headline lookup checks the office identifier first, so when both are unusable the error names the
office. Identifiers are encoded as one path segment each and are not upper-cased or otherwise
normalized. An identifier the service does not recognize is sent, and the service's refusal arrives
as ``NWSError/problem(_:)``.

### Office metadata

An office's identifier and name are always present. Every other field is optional, and is nil only
when the service omits it or sends `null`. Values the service does send are kept as sent: an office
whose fax number is an empty string reports `""`, not nil, so an empty value and a missing one stay
distinct.

The office's zone, station, and parent office fields are links to other API resources. The client
follows none of them. To read one, turn it into an endpoint, which validates that it stays on the
API origin:

```swift
if let link = office.responsibleForecastZones?.first,
  let endpoint = Endpoint<Feature<WeatherZone>>(accept: .geoJSON, link: link)
{
  let zone = try await weather.send(endpoint)
}
```

The office's website, `sameAs`, points outside the API origin and is for a reader, not the client.
It is text, kept exactly as the service sent it.

### Headlines

``NWSClient/officeHeadlines(officeIdentifier:)`` returns the headlines in the order the service
listed them. An office with nothing to say answers an empty list. The client does not sort them,
filter them by importance or issuance time, or fall back to another office.

A headline carries two kinds of link, and they mean different things:

- `url`, decoded from the response's `@id`, is the headline's identity in the API. It is a resource
  you can request, after turning it into a validated endpoint.
- `link` is editorial content for a reader. It can point outside the API origin, and the client never
  sends a request to it. It is text, kept exactly as sent, so an empty or malformed link never fails
  the headline or its list.

```swift
let headline = try await weather.officeHeadline(
  identifier: "ab45482ca5f57ff412eb1320721d5ac9", officeIdentifier: "EWX")

if let identity = headline.url,
  let endpoint = Endpoint<OfficeHeadline>(accept: .jsonLD, link: identity)
{
  let again = try await weather.send(endpoint)
}
```

A headline's `content` is HTML, returned exactly as the service sent it, including its markup and
percent escapes. The client does not render, escape, strip, or sanitize it, and it follows none of
the links inside it. Presenting it is your app's decision: text placed directly into a control that
does not interpret markup shows the tags instead of the meaning. A headline's `summary` can be nil
even when the headline has content.

### Briefings

``NWSClient/officeBriefing(officeIdentifier:)`` returns the metadata for the office's current
weather briefing: its identifier, office, title, description, priority, the times it starts, ends,
and was last updated, and a `download` link to the briefing's document.

```swift
if let briefing = try await weather.officeBriefing(officeIdentifier: "LWX") {
  print(briefing.title ?? "Untitled briefing")
  if let download = briefing.download {
    print(download)
  }
} else {
  print("No current briefing")
}
```

An office with no current briefing answers `null`, and the method returns nil after that one
request. Nil is an answer, not a failure: the client does not retry, ask another office, or fall
back to any other route. An office the service does not recognize is still a refusal, and its `404`
arrives as ``NWSError/problem(_:)`` rather than nil.

Every field of the metadata is optional, and is nil only when the service omits it or sends `null`.
The dates decode as ISO 8601, and a present value of the wrong type fails the response to decode.

`download` is a URL and nothing more. The client never requests it and does not retrieve, open, or
parse briefing documents. The document it names is a PDF, which this package does not support. To
show the briefing, hand the URL to your own networking stack, a web view, or the system browser.

### Supported office routes

| Route | Supported |
|---|---|
| `/offices/{officeId}` | Yes |
| `/offices/{officeId}/headlines` | Yes |
| `/offices/{officeId}/headlines/{headlineId}` | Yes |
| `/offices/{officeId}/briefing` | Yes, as metadata |
| `/offices/{officeId}/briefing/download/latest` | No |
| `/offices/{officeId}/briefing/download/{briefingId}` | No |
| `/offices/{officeId}/weatherstories` | No |
| `/offices/{officeId}/weatherstories/download/{imageId}` | No |

### What the office operations do not do

- The headline list is one response. The service documents no page size and no cursor for
  `/offices/{officeId}/headlines`, so neither is sent and there are no headline page or item
  sequences. That describes the request, not a guarantee about how many headlines come back. See
  <doc:PaginatingCollections> for the collections that do continue.
- Briefing documents are not supported. Neither `/offices/{officeId}/briefing/download/latest` nor
  `/offices/{officeId}/briefing/download/{briefingId}` is requested, including through a briefing's
  `download` link.
- Weather stories (`/offices/{officeId}/weatherstories` and its image download) are not supported.
- No PDF or image is ever downloaded. Nothing is fetched beyond the one request each operation
  sends.
- Nothing is cached. ``PointCache`` covers coordinate lookups only.

Redirects, refusals, and cancellation behave as they do for every other request. A redirect is
validated against the HTTPS API origin, and one that leaves it throws ``NWSError/invalidLink(_:)``
rather than being followed. Cancellation is checked before the request is sent.
