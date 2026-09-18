import Foundation
import SwiftNWSModels
import SwiftNWSTestSupport
import Testing

@Suite("Observation-history queries", .timeLimit(.minutes(suiteTimeLimitMinutes)))
struct ObservationQueryTests {
  @Test("Both page-size boundaries are accepted", arguments: [1, 500])
  func bothPageSizeBoundariesAreAccepted(limit: Int) throws {
    #expect(try ObservationQuery(limit: limit, stationIdentifier: "KATT").limit == limit)
  }

  @Test("Defaults send only the station with an open window and the service's page size")
  func defaultsSendOnlyTheStationWithAnOpenWindowAndTheServicesPageSize() throws {
    let query = try ObservationQuery(stationIdentifier: "KATT")
    #expect(query.cursor == nil)
    #expect(query.end == nil)
    #expect(query.limit == nil)
    #expect(query.start == nil)
    #expect(query.stationIdentifier == "KATT")
    #expect(Endpoint.observations(query: query).path == "/stations/KATT/observations")
    #expect(Set([query, try ObservationQuery(stationIdentifier: "KATT")]).count == 1)
  }

  @Test("An empty station identifier fails")
  func anEmptyStationIdentifierFails() {
    #expect(throws: ObservationQuery.ValidationError.invalidStationIdentifier) {
      try ObservationQuery(stationIdentifier: "")
    }
  }

  @Test("Limits outside the provider range fail", arguments: [Int.min, -1, 0, 501, Int.max])
  func limitsOutsideTheProviderRangeFail(limit: Int) {
    #expect(throws: ObservationQuery.ValidationError.invalidLimit) {
      try ObservationQuery(limit: limit, stationIdentifier: "KATT")
    }
  }

  @Test("Station identifiers occupy exactly one path segment")
  func stationIdentifiersOccupyExactlyOnePathSegment() throws {
    let query = try ObservationQuery(stationIdentifier: "../A/B?x=#%\n")
    #expect(
      Endpoint.observations(query: query).path
        == "/stations/%2E%2E%2FA%2FB%3Fx%3D%23%25%0A/observations")
  }

  @Test("Window bounds, page size, and the initial cursor retain their supplied values")
  func windowBoundsPageSizeAndTheInitialCursorRetainTheirSuppliedValues() throws {
    // 2026-09-16T00:00:00Z and 2026-09-17T00:00:00.75Z, sent with whole-second precision.
    let start = Date(timeIntervalSince1970: 1_789_516_800)
    let end = Date(timeIntervalSince1970: 1_789_603_200.75)
    let query = try ObservationQuery(
      cursor: "a/b?&=+", end: end, limit: 2, start: start, stationIdentifier: "KATT")
    #expect(
      Endpoint.observations(query: query).path
        == "/stations/KATT/observations?cursor=a/b?%26%3D%2B&end=2026-09-17T00:00:00Z&limit=2"
        + "&start=2026-09-16T00:00:00Z")
    let request = WeatherRequest.observations(query: query)
    #expect(request.resolution == .observations(query))
  }
}
