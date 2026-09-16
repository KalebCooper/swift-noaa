import SwiftNWSModels
import SwiftNWSTestSupport
import Testing

@Suite("Observation-station queries", .timeLimit(.minutes(suiteTimeLimitMinutes)))
struct ObservationStationQueryTests {
  @Test("Both page-size boundaries are accepted", arguments: [1, 500])
  func bothPageSizeBoundariesAreAccepted(limit: Int) throws {
    #expect(try ObservationStationQuery(limit: limit).limit == limit)
  }

  @Test("Defaults request the maximum page size without filters")
  func defaultsRequestTheMaximumPageSizeWithoutFilters() throws {
    let query = try ObservationStationQuery()
    #expect(query.cursor == nil)
    #expect(query.identifiers.isEmpty)
    #expect(query.limit == 500)
    #expect(query.states.isEmpty)
    #expect(Endpoint.observationStations(query: query).path == "/stations?limit=500")
    #expect(Set([query, try ObservationStationQuery()]).count == 1)
  }

  @Test("Filters and initial cursor retain their supplied values")
  func filtersAndInitialCursorRetainTheirSuppliedValues() throws {
    let query = try ObservationStationQuery(
      cursor: "a/b?&=+", identifiers: ["KATT", "KDCA"], limit: 1,
      states: [.init(rawValue: "TX"), .init(rawValue: "VA")])
    #expect(
      Endpoint.observationStations(query: query).path
        == "/stations?cursor=a/b?%26%3D%2B&id=KATT,KDCA&limit=1&state=TX,VA")
    let request = WeatherRequest.observationStations(query: query)
    #expect(request.resolution == .observationStations(query))
  }

  @Test("Limits outside the provider range fail", arguments: [Int.min, -1, 0, 501, Int.max])
  func limitsOutsideTheProviderRangeFail(limit: Int) {
    #expect(throws: ObservationStationQuery.ValidationError.invalidLimit) {
      try ObservationStationQuery(limit: limit)
    }
  }
}
