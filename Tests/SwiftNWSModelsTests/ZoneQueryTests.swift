import Foundation
import SwiftNWSModels
import SwiftNWSTestSupport
import Testing

@Suite("Zone queries", .timeLimit(.minutes(suiteTimeLimitMinutes)))
struct ZoneQueryTests {
  // 2026-09-20T00:00:00.5Z, sent with whole-second precision.
  private let effective = Date(timeIntervalSince1970: 1_789_862_400.5)

  @Test("Defaults send no query and compare equal")
  func defaultsSendNoQueryAndCompareEqual() throws {
    let query = try ZoneQuery()
    #expect(query.areas.isEmpty)
    #expect(query.effective == nil)
    #expect(query.identifiers.isEmpty)
    #expect(query.includesGeometry == nil)
    #expect(query.limit == nil)
    #expect(query.point == nil)
    #expect(query.regions.isEmpty)
    #expect(Endpoint.zones(matching: query).path == "/zones")
    #expect(Endpoint.zones(matching: query, ofType: .forecast)?.path == "/zones/forecast")
    #expect(Set([query, try ZoneQuery()]).count == 1)
  }

  @Test("Every filter is sent alphabetically by wire name with comma-separated values")
  func everyFilterIsSentAlphabeticallyByWireNameWithCommaSeparatedValues() throws {
    let query = try ZoneQuery(
      areas: [.texas, .oklahoma], effective: effective, identifiers: ["TXZ192", "TXC453"],
      includesGeometry: true, limit: 10,
      point: try WeatherCoordinate(latitude: 30.26721, longitude: -97.74306),
      regions: [.southernRegion, .gulfOfMexico])

    #expect(
      Endpoint.zones(matching: query, types: [.county, .fire]).path
        == "/zones?area=TX,OK&effective=2026-09-20T00:00:00Z&id=TXZ192,TXC453"
        + "&include_geometry=true&limit=10&point=30.2672,-97.7431&region=SR,GM&type=county,fire")
  }

  @Test("The typed route sends the query without repeating its type as a filter")
  func theTypedRouteSendsTheQueryWithoutRepeatingItsTypeAsAFilter() throws {
    let query = try ZoneQuery(areas: [.texas], limit: 2)
    #expect(
      Endpoint.zones(matching: query, ofType: .forecast)?.path == "/zones/forecast?area=TX&limit=2")
    #expect(
      Endpoint.zones(matching: query, ofType: .county)?.path == "/zones/county?area=TX&limit=2")
    #expect(Endpoint.zones(matching: query).path == "/zones?area=TX&limit=2")
  }

  @Test(
    "An explicit false geometry option is sent, and nil omits it", arguments: [nil, false, true])
  func anExplicitFalseGeometryOptionIsSentAndNilOmitsIt(includesGeometry: Bool?) throws {
    let query = try ZoneQuery(includesGeometry: includesGeometry)
    let expected = includesGeometry.map { "/zones?include_geometry=\($0)" } ?? "/zones"
    #expect(Endpoint.zones(matching: query).path == expected)
  }

  @Test("Identifier values are percent-encoded without becoming path segments")
  func identifierValuesArePercentEncodedWithoutBecomingPathSegments() throws {
    let query = try ZoneQuery(identifiers: ["A&B", "C=D", "E/F?G", "H+I"])
    #expect(Endpoint.zones(matching: query).path == "/zones?id=A%26B,C%3DD,E/F?G,H%2BI")
  }

  @Test("Limits below one fail", arguments: [Int.min, -1, 0])
  func limitsBelowOneFail(limit: Int) {
    #expect(throws: ZoneQuery.ValidationError.invalidLimit) {
      try ZoneQuery(limit: limit)
    }
  }

  @Test(
    "Limits of one and above are accepted without a maximum", arguments: [1, 500, 501, Int.max])
  func limitsOfOneAndAboveAreAcceptedWithoutAMaximum(limit: Int) throws {
    #expect(try ZoneQuery(limit: limit).limit == limit)
  }

  @Test("A point is sent with four-decimal precision")
  func aPointIsSentWithFourDecimalPrecision() throws {
    let query = try ZoneQuery(point: try WeatherCoordinate(latitude: 30, longitude: -97.5))
    #expect(Endpoint.zones(matching: query).path == "/zones?point=30,-97.5")
  }

  @Test("Consumer String-backed enums select types at the endpoint level")
  func consumerStringBackedEnumsSelectTypesAtTheEndpointLevel() throws {
    let query = try ZoneQuery(limit: 1)
    #expect(
      Endpoint.zones(matching: query, types: [AppZoneType.county]).path
        == "/zones?limit=1&type=county")
    #expect(
      Endpoint.zones(matching: query, ofType: AppZoneType.county)?.path == "/zones/county?limit=1")
  }

  @Test("No cursor parameter exists on the directory")
  func noCursorParameterExistsOnTheDirectory() throws {
    let query = try ZoneQuery(areas: [.texas], limit: 3)
    #expect(!Endpoint.zones(matching: query).path.contains("cursor"))
    #expect(WeatherRequest.zones(matching: query).resolution == .endpoint(.zones(matching: query)))
  }
}

private enum AppZoneType: String {
  case county
}
