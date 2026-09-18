import Foundation
import SwiftNWSModels
import SwiftNWSTestSupport
import Testing

@Suite("Alert-history queries", .timeLimit(.minutes(suiteTimeLimitMinutes)))
struct AlertQueryTests {
  @Test("Both page-size boundaries are accepted", arguments: [1, 500])
  func bothPageSizeBoundariesAreAccepted(limit: Int) throws {
    #expect(try AlertQuery(limit: limit).limit == limit)
  }

  @Test("Defaults request the maximum page size with an open window and no filters")
  func defaultsRequestTheMaximumPageSizeWithAnOpenWindowAndNoFilters() throws {
    let query = try AlertQuery()
    #expect(query.cursor == nil)
    #expect(query.end == nil)
    #expect(query.filter == ActiveAlertFilter())
    #expect(query.limit == 500)
    #expect(query.start == nil)
    #expect(Endpoint.alerts(matching: query).path == "/alerts?limit=500")
    #expect(Set([query, try AlertQuery()]).count == 1)
  }

  @Test("Filters, window bounds, and the initial cursor retain their supplied values")
  func filtersWindowBoundsAndTheInitialCursorRetainTheirSuppliedValues() throws {
    // 2026-09-16T00:00:00Z and 2026-09-17T00:00:00Z.
    let start = Date(timeIntervalSince1970: 1_789_516_800)
    let end = Date(timeIntervalSince1970: 1_789_603_200)
    let filter = ActiveAlertFilter(location: .areas([.texas]), status: [.actual])
    let query = try AlertQuery(cursor: "a/b?&=+", end: end, filter: filter, limit: 2, start: start)
    #expect(
      Endpoint.alerts(matching: query).path
        == "/alerts?area=TX&cursor=a/b?%26%3D%2B&end=2026-09-17T00:00:00Z&limit=2"
        + "&start=2026-09-16T00:00:00Z&status=actual")
    let request = WeatherRequest.alerts(matching: query)
    #expect(request.resolution == .alerts(query))
  }

  @Test("Limits outside the provider range fail", arguments: [Int.min, -1, 0, 501, Int.max])
  func limitsOutsideTheProviderRangeFail(limit: Int) {
    #expect(throws: AlertQuery.ValidationError.invalidLimit) {
      try AlertQuery(limit: limit)
    }
  }

  @Test("Window bounds are sent with whole-second precision")
  func windowBoundsAreSentWithWholeSecondPrecision() throws {
    let query = try AlertQuery(start: Date(timeIntervalSince1970: 1_789_516_800.75))
    #expect(Endpoint.alerts(matching: query).path == "/alerts?limit=500&start=2026-09-16T00:00:00Z")
  }
}
