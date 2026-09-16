import SwiftNWS
import SwiftNWSModels
import SwiftNWSTestSupport
import Testing

@Suite("Pagination foundation", .timeLimit(.minutes(suiteTimeLimitMinutes)))
struct PaginationTests {
  @Test(
    "SDK pagination errors preserve their portable cause",
    arguments: [
      NWSPaginationError.invalidNext("not a link"), .missingNext,
      .repeatedNext("https://api.weather.gov/stations?cursor=again"),
    ])
  func sdkPaginationErrorsPreserveTheirPortableCause(expected: NWSPaginationError) {
    let error = NWSError.pagination(expected)

    guard case .pagination(let actual) = error else {
      Issue.record("Expected a pagination error")
      return
    }
    #expect(actual == expected)
  }
}
