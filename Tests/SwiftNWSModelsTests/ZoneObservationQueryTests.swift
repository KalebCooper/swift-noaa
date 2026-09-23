import Foundation
import SwiftNWSModels
import SwiftNWSTestSupport
import Testing

@Suite("Zone observation queries", .timeLimit(.minutes(suiteTimeLimitMinutes)))
struct ZoneObservationQueryTests {
  // 2026-09-20T00:00:00.5Z, sent with whole-second precision.
  private let end = Date(timeIntervalSince1970: 1_789_862_400.5)
  // 2026-09-19T00:00:00Z.
  private let start = Date(timeIntervalSince1970: 1_789_776_000)

  @Test("Defaults send only the zone path and compare equal")
  func defaultsSendOnlyTheZonePathAndCompareEqual() throws {
    let query = try ZoneObservationQuery(zoneIdentifier: "TXZ192")
    #expect(query.end == nil)
    #expect(query.limit == nil)
    #expect(query.start == nil)
    #expect(query.zoneIdentifier == "TXZ192")
    #expect(
      Endpoint.observations(inForecastZone: query).path == "/zones/forecast/TXZ192/observations")
    #expect(Set([query, try ZoneObservationQuery(zoneIdentifier: "TXZ192")]).count == 1)
  }

  @Test("A window and limit are sent alphabetically with whole-second UTC instants")
  func aWindowAndLimitAreSentAlphabeticallyWithWholeSecondUTCInstants() throws {
    let query = try ZoneObservationQuery(
      end: end, limit: 3, start: start, zoneIdentifier: "TXZ192")
    #expect(
      Endpoint.observations(inForecastZone: query).path
        == "/zones/forecast/TXZ192/observations?end=2026-09-20T00:00:00Z&limit=3&start=2026-09-19T00:00:00Z"
    )
  }

  @Test("A reversed window is sent unchanged for the service to validate")
  func aReversedWindowIsSentUnchangedForTheServiceToValidate() throws {
    let query = try ZoneObservationQuery(end: start, start: end, zoneIdentifier: "TXZ192")
    #expect(
      Endpoint.observations(inForecastZone: query).path
        == "/zones/forecast/TXZ192/observations?end=2026-09-19T00:00:00Z&start=2026-09-20T00:00:00Z"
    )
  }

  @Test("Limits at the bounds are accepted", arguments: [1, 500])
  func limitsAtTheBoundsAreAccepted(limit: Int) throws {
    let query = try ZoneObservationQuery(limit: limit, zoneIdentifier: "TXZ192")
    #expect(query.limit == limit)
    #expect(
      Endpoint.observations(inForecastZone: query).path
        == "/zones/forecast/TXZ192/observations?limit=\(limit)")
  }

  @Test("Limits outside 1 through 500 fail", arguments: [Int.min, -1, 0, 501, Int.max])
  func limitsOutside1Through500Fail(limit: Int) {
    #expect(throws: ZoneObservationQuery.ValidationError.invalidLimit) {
      try ZoneObservationQuery(limit: limit, zoneIdentifier: "TXZ192")
    }
  }

  @Test("An empty or unusable zone identifier fails", arguments: ["", ".", "..", "\\"])
  func anEmptyOrUnusableZoneIdentifierFails(identifier: String) {
    #expect(throws: ZoneObservationQuery.ValidationError.invalidZoneIdentifier) {
      try ZoneObservationQuery(zoneIdentifier: identifier)
    }
  }

  @Test("The zone identifier occupies one path segment and keeps its case")
  func theZoneIdentifierOccupiesOnePathSegmentAndKeepsItsCase() throws {
    #expect(
      Endpoint.observations(inForecastZone: try ZoneObservationQuery(zoneIdentifier: "A/B?x=#%"))
        .path == "/zones/forecast/A%2FB%3Fx%3D%23%25/observations")
    #expect(
      Endpoint.observations(inForecastZone: try ZoneObservationQuery(zoneIdentifier: "txz192"))
        .path == "/zones/forecast/txz192/observations")
  }

  @Test("No cursor parameter exists on the zone observation list")
  func noCursorParameterExistsOnTheZoneObservationList() throws {
    let query = try ZoneObservationQuery(limit: 2, zoneIdentifier: "TXZ192")
    let mirror = Mirror(reflecting: query)
    #expect(mirror.children.map(\.label) == ["end", "limit", "start", "zoneIdentifier"])
    #expect(!Endpoint.observations(inForecastZone: query).path.contains("cursor"))
  }
}
