import Foundation
import SwiftNOAATidesModels
import SwiftNOAATidesTestSupport
import Testing

@Suite("High and low tide models", .timeLimit(.minutes(suiteTimeLimitMinutes)))
struct HighLowTideTests {
  @Test("Calendar limits use GMT years and retain leap-day semantics")
  func calendarLimitsUseGMTYearsAndRetainLeapDaySemantics() throws {
    let begin = try TidesTimestamp("2016-02-29 12:00").date
    let end = try TidesTimestamp("2026-02-28 12:00").date
    let station = try CoastalStationIdentifier("9414290")
    let range = try TidesDateRange(begin: begin, end: end)
    let query = try HighLowTideQuery(
      datum: .meanLowerLowWater, range: range, stationIdentifier: station, units: .metric)
    #expect(query.range.end == end)
    let tooLong = try TidesDateRange(begin: begin, end: end.addingTimeInterval(60))
    #expect(throws: TidesQueryError.rangeTooLong(maximumMonths: 120)) {
      try HighLowTideQuery(
        datum: .meanLowerLowWater, range: tooLong, stationIdentifier: station, units: .metric)
    }
  }

  @Test("Empty events and unknown event codes remain observable")
  func emptyEventsAndUnknownEventCodesRemainObservable() throws {
    let empty = try JSONDecoder().decode(
      HighLowTideResponse.self, from: Data(#"{"predictions":[]}"#.utf8))
    #expect(empty.predictions.isEmpty)
    let unknown = try JSONDecoder().decode(
      HighLowTideResponse.self,
      from: Data(#"{"predictions":[{"t":"2024-02-29 12:00","v":"-0.010","type":"future"}]}"#.utf8))
    #expect(unknown.predictions.first?.kind.rawValue == "future")
    #expect(unknown.predictions.first?.height.rawValue == "-0.010")
    #expect(unknown.predictions.first?.height.value == -0.01)
    #expect(
      try JSONDecoder().decode(HighLowTideResponse.self, from: JSONEncoder().encode(unknown))
        == unknown)
  }

  @Test("Invalid ranges and codes fail during query construction")
  func invalidRangesAndCodesFailDuringQueryConstruction() throws {
    let begin = Date(timeIntervalSince1970: 1_790_380_800)
    #expect(throws: TidesQueryError.invalidDateRange) {
      try TidesDateRange(begin: begin, end: begin)
    }
    #expect(throws: TidesQueryError.invalidDateRange) {
      try TidesDateRange(begin: begin, end: begin.addingTimeInterval(-60))
    }
    #expect(throws: TidesQueryError.nonMinuteAlignedDate) {
      try TidesDateRange(begin: begin, end: begin.addingTimeInterval(60.5))
    }
    let range = try TidesDateRange(begin: begin, end: begin.addingTimeInterval(60))
    let station = try CoastalStationIdentifier("9414290")
    #expect(throws: TidesQueryError.invalidDatum("")) {
      try HighLowTideQuery(
        datum: .init(rawValue: ""), range: range, stationIdentifier: station, units: .metric)
    }
    #expect(throws: TidesQueryError.invalidUnits("\n")) {
      try HighLowTideQuery(
        datum: .meanLowerLowWater, range: range, stationIdentifier: station,
        units: .init(rawValue: "\n"))
    }
  }

  @Test(
    "Invalid timestamps never normalize into another minute",
    arguments: [
      "2023-02-29 12:00", "2024-02-30 12:00", "2024-13-01 00:00", "2024-01-01 24:00",
      "2024-01-01 00:60", "2024-01-01T00:00Z", "2024-01-01 00:00:00", "0000-01-01 00:00",
    ])
  func invalidTimestampsNeverNormalizeIntoAnotherMinute(text: String) {
    #expect(throws: TidesQueryError.invalidTimestamp(text)) { try TidesTimestamp(text) }
  }

  @Test(
    "Malformed prediction envelopes fail instead of becoming empty",
    arguments: [
      #"{}"#, #"{"predictions":null}"#, #"{"predictions":[{"t":"2024-01-01 00:00","v":"1"}]}"#,
      #"{"predictions":[{"t":"2024-01-01 00:00","v":1,"type":"H"}]}"#,
    ])
  func malformedPredictionEnvelopesFailInsteadOfBecomingEmpty(body: String) {
    #expect(throws: DecodingError.self) {
      try JSONDecoder().decode(HighLowTideResponse.self, from: Data(body.utf8))
    }
  }

  @Test(
    "Numeric text rejects missing malformed and nonfinite values",
    arguments: ["", "NaN", "Infinity", "1e999", " 1", "1 ", "01", "1.2.3", "--1", "+1", "null"])
  func numericTextRejectsMissingMalformedAndNonfiniteValues(text: String) {
    #expect(throws: TidesQueryError.invalidNumber(text)) { try TidesNumericValue(text) }
  }

  @Test("Recorded events decode without executor or decoder date context")
  func recordedEventsDecodeWithoutExecutorOrDecoderDateContext() throws {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .custom { _ in throw TestFailure.unexpectedDateStrategy }
    let response = try decoder.decode(HighLowTideResponse.self, from: Fixture.tideHighLow.data())
    #expect(response.predictions.count == 8)
    #expect(response.predictions.first?.time.date == Date(timeIntervalSince1970: 1_790_381_820))
    #expect(response.predictions.first?.time.rawValue == "2026-09-26 00:17")
    #expect(response.predictions.first?.height.rawValue == "0.377")
    #expect(response.predictions.first?.height.value == 0.377)
    #expect(response.predictions.first?.kind == .low)
    #expect(response.predictions.last?.kind == .high)
    let subordinate = try decoder.decode(
      HighLowTideResponse.self, from: Fixture.tideSubordinate.data())
    #expect(subordinate.predictions.count == 7)
    #expect(subordinate.predictions.first?.height.value == 0.102)
    let english = try decoder.decode(HighLowTideResponse.self, from: Fixture.tideEnglish.data())
    #expect(english.predictions.count == 4)
    #expect(english.predictions.first?.height.value == 5.572)
  }

  @Test("Request inference and consumer codes retain the validated query")
  func requestInferenceAndConsumerCodesRetainTheValidatedQuery() throws {
    enum Datum: String { case local = "CUSTOM" }
    let range = try TidesDateRange(
      begin: TidesTimestamp("2024-03-10 01:00").date, end: TidesTimestamp("2024-03-10 03:00").date)
    let query = try HighLowTideQuery(
      datum: TideDatum(Datum.local), range: range,
      stationIdentifier: CoastalStationIdentifier("Ab-1"), units: .english)
    let request = TidesRequest.highLowTides(matching: query)
    let _: TidesRequest<HighLowTides> = request
    #expect(request.resolution == .highLowTides(query))
    #expect(Set([request, request]).count == 1)
    let endpoint = TidesEndpoint.highLowTides(matching: query)
    #expect(
      endpoint.path
        == "/api/prod/datagetter?begin_date=20240310%2001:00&datum=CUSTOM&end_date=20240310%2003:00&format=json&interval=hilo&product=predictions&station=Ab-1&time_zone=gmt&units=english"
    )
  }

  private enum TestFailure: Error { case unexpectedDateStrategy }
}
