import Foundation
import SwiftNOAATidesModels
import SwiftNOAATidesTestSupport
import Testing

@Suite("One-minute water levels", .timeLimit(.minutes(suiteTimeLimitMinutes)))
struct OneMinuteWaterLevelTests {
  @Test(
    "Four-day boundaries include leap days and midnight",
    arguments: [
      ["2024-02-28 00:00", "2024-03-03 00:00"],
      ["2025-01-30 00:00", "2025-02-03 00:00"],
      ["2025-03-08 12:34", "2025-03-12 12:34"],
    ])
  func fourDayBoundariesIncludeLeapDaysAndMidnight(bounds: [String]) throws {
    let begin = try TidesTimestamp(bounds[0]).date
    let end = try TidesTimestamp(bounds[1]).date
    let station = try CoastalStationIdentifier("9414290")
    let range = try TidesDateRange(begin: begin, end: end)
    let query = try OneMinuteWaterLevelQuery(
      datum: .meanLowerLowWater, range: range, stationIdentifier: station, units: .metric)
    #expect(query.range == range)
    #expect(throws: TidesQueryError.rangeTooLongDays(maximumDays: 4)) {
      try OneMinuteWaterLevelQuery(
        datum: .meanLowerLowWater,
        range: TidesDateRange(begin: begin, end: end.addingTimeInterval(60)),
        stationIdentifier: station, units: .metric)
    }
    #expect(throws: TidesQueryError.nonMinuteAlignedDate) {
      try TidesDateRange(begin: begin, end: end.addingTimeInterval(1))
    }
  }

  @Test("Invalid open codes fail at construction")
  func invalidOpenCodesFailAtConstruction() throws {
    let station = try CoastalStationIdentifier("9414290")
    let range = try TidesDateRange(
      begin: TidesTimestamp("2025-01-01 00:00").date, end: TidesTimestamp("2025-01-01 00:05").date)
    for code in ["", "\n", "bad\u{7F}"] {
      #expect(throws: TidesQueryError.invalidDatum(code)) {
        try OneMinuteWaterLevelQuery(
          datum: TideDatum(rawValue: code), range: range, stationIdentifier: station, units: .metric
        )
      }
      #expect(throws: TidesQueryError.invalidUnits(code)) {
        try OneMinuteWaterLevelQuery(
          datum: .meanLowerLowWater, range: range, stationIdentifier: station,
          units: TidesUnits(rawValue: code))
      }
    }
  }

  @Test("Missing and malformed fields are distinct")
  func missingAndMalformedFieldsAreDistinct() throws {
    for raw in ["", "0", "-1.25"] {
      let body = try JSONSerialization.data(withJSONObject: ["t": "2025-01-01 00:00", "v": raw])
      let sample = try JSONDecoder().decode(OneMinuteWaterLevel.self, from: body)
      #expect(sample.height.rawValue == raw)
      #expect(sample.height.value == Double(raw))
    }
    for raw in [
      #"{"v":"1"}"#, #"{"t":"bad","v":"1"}"#,
      #"{"t":"2025-01-01 00:00"}"#, #"{"t":"2025-01-01 00:00","v":null}"#,
      #"{"t":"2025-01-01 00:00","v":"NaN"}"#, #"{"t":"2025-01-01 00:00","v":1}"#,
    ] {
      #expect(throws: DecodingError.self) {
        try JSONDecoder().decode(OneMinuteWaterLevel.self, from: Data(raw.utf8))
      }
    }
    for suffix in ["", #","data":null"#] {
      let text =
        #"{"metadata":{"id":"reported","name":"Reported","lat":"1","lon":"2"}"# + suffix + "}"
      #expect(throws: DecodingError.self) {
        try JSONDecoder().decode(OneMinuteWaterLevelResponse.self, from: Data(text.utf8))
      }
    }
  }

  @Test("Recorded missing minutes retain empty quantities")
  func recordedMissingMinutesRetainEmptyQuantities() throws {
    let response = try JSONDecoder().decode(
      OneMinuteWaterLevelResponse.self, from: Fixture.oneMinuteMissing.data())
    let sample = try #require(
      response.observations.first { $0.time.rawValue == "2024-02-28 00:31" })
    #expect(sample.height.rawValue == "")
    #expect(sample.height.value == nil)
    #expect(response.observations.last?.time.rawValue == "2024-02-28 05:20")
  }

  @Test(
    "Recordings have only height and time in both unit systems",
    arguments: [Fixture.oneMinuteMetric, .oneMinuteEnglish])
  func recordingsHaveOnlyHeightAndTimeInBothUnitSystems(fixture: Fixture) throws {
    let response = try JSONDecoder().decode(OneMinuteWaterLevelResponse.self, from: fixture.data())
    #expect(response.observations.count == 6)
    #expect(response.metadata.identifier == "9414290")
    #expect(
      response.observations.first?.height.rawValue
        == (fixture == .oneMinuteMetric ? "0.041" : "0.136"))
    #expect(response.observations[1].time.rawValue == "2025-01-01 00:01")
    #expect(
      try JSONDecoder().decode(
        OneMinuteWaterLevelResponse.self, from: JSONEncoder().encode(response)) == response)
    let sample = try #require(response.observations.first)
    let fields = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(sample)) as? [String: Any])
    #expect(Set(fields.keys) == ["t", "v"])
  }
}
