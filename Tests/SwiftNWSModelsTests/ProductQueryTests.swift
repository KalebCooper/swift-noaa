import Foundation
import SwiftNWSModels
import SwiftNWSTestSupport
import Testing

@Suite("Product queries", .timeLimit(.minutes(suiteTimeLimitMinutes)))
struct ProductQueryTests {
  // 2026-09-17T00:00:00.5Z, sent with whole-second precision.
  private let end = Date(timeIntervalSince1970: 1_789_603_200.5)
  // 2026-09-16T00:00:00Z.
  private let start = Date(timeIntervalSince1970: 1_789_516_800)

  @Test("An unfiltered query sends no query items and compares equal")
  func anUnfilteredQuerySendsNoQueryItemsAndComparesEqual() throws {
    let query = try ProductQuery()

    #expect(query.end == nil)
    #expect(query.issuingOffices.isEmpty)
    #expect(query.limit == nil)
    #expect(query.locations.isEmpty)
    #expect(query.start == nil)
    #expect(query.types.isEmpty)
    #expect(query.wmoCollectiveIdentifiers.isEmpty)
    #expect(Endpoint.products(matching: query).path == "/products")
    #expect(Set([query, try ProductQuery()]).count == 1)
  }

  @Test("Every filter reaches the parameter the service documents")
  func everyFilterReachesTheParameterTheServiceDocuments() throws {
    let query = try ProductQuery(
      end: end, issuingOffices: ["KEWX", "KOUN"], limit: 2, locations: ["EWX", "OUN"],
      start: start, types: [.areaForecastDiscussion, .publicZoneForecast],
      wmoCollectiveIdentifiers: ["FXUS64", "FXUS63"])

    #expect(
      Endpoint.products(matching: query).path
        == "/products?end=2026-09-17T00:00:00Z&limit=2&location=EWX,OUN&office=KEWX,KOUN"
        + "&start=2026-09-16T00:00:00Z&type=AFD,ZFP&wmoid=FXUS64,FXUS63")
  }

  @Test("Filters retain the order they were supplied in")
  func filtersRetainTheOrderTheyWereSuppliedIn() throws {
    let query = try ProductQuery(
      locations: ["OUN", "EWX"], types: [.publicZoneForecast, .areaForecastDiscussion])

    #expect(query.locations == ["OUN", "EWX"])
    #expect(query.types == [.publicZoneForecast, .areaForecastDiscussion])
    #expect(Endpoint.products(matching: query).path == "/products?location=OUN,EWX&type=ZFP,AFD")
  }

  @Test("A nil limit omits the parameter the route documents no default for")
  func aNilLimitOmitsTheParameterTheRouteDocumentsNoDefaultFor() throws {
    let query = try ProductQuery(locations: ["EWX"])

    #expect(query.limit == nil)
    #expect(Endpoint.products(matching: query).path == "/products?location=EWX")
  }

  @Test("Limits at the bounds are accepted", arguments: [1, 500])
  func limitsAtTheBoundsAreAccepted(limit: Int) throws {
    let query = try ProductQuery(limit: limit)

    #expect(query.limit == limit)
    #expect(Endpoint.products(matching: query).path == "/products?limit=\(limit)")
  }

  @Test("Limits outside 1 through 500 fail", arguments: [Int.min, -1, 0, 501, Int.max])
  func limitsOutside1Through500Fail(limit: Int) {
    #expect(throws: ProductQuery.ValidationError.invalidLimit) {
      try ProductQuery(limit: limit)
    }
  }

  @Test("Window bounds are sent as whole-second UTC instants")
  func windowBoundsAreSentAsWholeSecondUTCInstants() throws {
    let query = try ProductQuery(end: end, start: Date(timeIntervalSince1970: 1_789_516_800.75))

    #expect(
      Endpoint.products(matching: query).path
        == "/products?end=2026-09-17T00:00:00Z&start=2026-09-16T00:00:00Z")
  }

  @Test("A reversed window is sent unchanged for the service to validate")
  func aReversedWindowIsSentUnchangedForTheServiceToValidate() throws {
    let query = try ProductQuery(end: start, start: end)

    #expect(
      Endpoint.products(matching: query).path
        == "/products?end=2026-09-16T00:00:00Z&start=2026-09-17T00:00:00Z")
  }

  @Test("A filter value is escaped rather than read as another parameter")
  func aFilterValueIsEscapedRatherThanReadAsAnotherParameter() throws {
    let query = try ProductQuery(locations: ["A&B=C"])

    #expect(Endpoint.products(matching: query).path == "/products?location=A%26B%3DC")
  }

  @Test("A query request carries the plain endpoint resolution")
  func aQueryRequestCarriesThePlainEndpointResolution() throws {
    let query = try ProductQuery(limit: 2, locations: ["EWX"], types: [.areaForecastDiscussion])

    #expect(
      WeatherRequest.products(matching: query).resolution
        == .endpoint(Endpoint.products(matching: query)))
  }
}
