import Foundation
import SwiftNOAATidesModels
import SwiftNOAATidesTestSupport
import Testing

@Suite("Coastal observation queries", .timeLimit(.minutes(suiteTimeLimitMinutes)))
struct CoastalObservationQueryTests {
  @Test("Calendar limits retain leap days and inclusive end boundaries")
  func calendarLimitsRetainLeapDaysAndInclusiveEndBoundaries() throws {
    let station = try CoastalStationIdentifier("1611400")
    for (interval, begin, end) in [
      (CoastalObservationInterval.sixMinutes, "2024-01-31 00:00", "2024-02-29 00:00"),
      (.hourly, "2024-02-29 00:00", "2025-02-28 00:00"),
    ] {
      let range = try TidesDateRange(
        begin: TidesTimestamp(begin).date, end: TidesTimestamp(end).date)
      _ = try CoastalObservationQuery(
        interval: interval, range: range, stationIdentifier: station, units: .metric)
      let over = try TidesDateRange(begin: range.begin, end: range.end.addingTimeInterval(60))
      #expect(throws: TidesQueryError.rangeTooLong(maximumMonths: interval == .hourly ? 12 : 1)) {
        try CoastalObservationQuery(
          interval: interval, range: over, stationIdentifier: station, units: .metric)
      }
    }
  }

  @Test("Invalid units fail and unknown unit codes remain explicit")
  func invalidUnitsFailAndUnknownUnitCodesRemainExplicit() throws {
    let station = try CoastalStationIdentifier("1611400")
    let range = try TidesDateRange(
      begin: TidesTimestamp("2025-01-01 00:00").date,
      end: TidesTimestamp("2025-01-01 01:00").date)
    for raw in ["", "m\n"] {
      #expect(throws: TidesQueryError.invalidUnits(raw)) {
        try CoastalObservationQuery(
          interval: .sixMinutes, range: range, stationIdentifier: station,
          units: .init(rawValue: raw))
      }
    }
    let query = try CoastalObservationQuery(
      interval: .hourly, range: range, stationIdentifier: station, units: .init(rawValue: "future"))
    #expect(
      TidesEndpoint.waterTemperatureObservations(matching: query).path.contains("units=future"))
  }
}
