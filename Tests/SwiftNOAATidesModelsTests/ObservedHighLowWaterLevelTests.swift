import Foundation
import SwiftNOAATidesModels
import SwiftNOAATidesTestSupport
import Testing

@Suite("Observed high and low levels", .timeLimit(.minutes(suiteTimeLimitMinutes)))
struct ObservedHighLowWaterLevelTests {
  @Test("Codes retain exact text while classification recognizes recorded padding")
  func codesRetainExactTextWhileClassificationRecognizesRecordedPadding() throws {
    let classifications: [String: ObservedHighLowWaterLevelKind.Classification] = [
      "H": .high, "H ": .high, "HH": .higherHigh, "L": .low, "L ": .low, "LL": .lowerLow,
    ]
    for raw in ["H", "H ", "HH", "L", "L ", "LL", "future", "", "H  "] {
      let value = ObservedHighLowWaterLevelKind(rawValue: raw)
      #expect(value.rawValue == raw)
      #expect(value.classification == classifications[raw])
      #expect(
        try JSONDecoder().decode(
          ObservedHighLowWaterLevelKind.self, from: JSONEncoder().encode(value)) == value)
    }
    #expect(ObservedHighLowWaterLevelKind(rawValue: "H ") != .high)
    enum ConsumerCode: String { case unfamiliar = "future" }
    #expect(ObservedHighLowWaterLevelKind(ConsumerCode.unfamiliar).rawValue == "future")
  }

  @Test("Malformed or absent event fields fail decoding")
  func malformedOrAbsentEventFieldsFailDecoding() throws {
    let original: [String: Any] = ["t": "2025-01-01 02:06", "v": "-0.35", "ty": "LL", "f": "0,0"]
    for key in ["t", "v", "ty", "f"] {
      var body = original
      body.removeValue(forKey: key)
      #expect(throws: DecodingError.self) {
        try JSONDecoder().decode(
          ObservedHighLowWaterLevel.self, from: JSONSerialization.data(withJSONObject: body))
      }
    }
    for value: Any in ["", "NaN", "bad", NSNull(), 1] {
      var body = original; body["v"] = value
      #expect(throws: DecodingError.self) {
        try JSONDecoder().decode(
          ObservedHighLowWaterLevel.self, from: JSONSerialization.data(withJSONObject: body))
      }
    }
    var body = original; body["t"] = "bad"
    #expect(throws: DecodingError.self) {
      try JSONDecoder().decode(
        ObservedHighLowWaterLevel.self, from: JSONSerialization.data(withJSONObject: body))
    }
    for suffix in ["", #","data":null"#] {
      let text =
        #"{"metadata":{"id":"reported","name":"Reported","lat":"1","lon":"2"}"# + suffix + "}"
      #expect(throws: DecodingError.self) {
        try JSONDecoder().decode(ObservedHighLowWaterLevelResponse.self, from: Data(text.utf8))
      }
    }
    body = original; body["v"] = "0"; body["ty"] = "future"; body["f"] = "future,flags"
    let event = try JSONDecoder().decode(
      ObservedHighLowWaterLevel.self, from: JSONSerialization.data(withJSONObject: body))
    #expect(event.height.value == 0)
    #expect(event.kind.rawValue == "future")
    #expect(event.flags == "future,flags")
  }

  @Test("Open query codes validate without narrowing the provider vocabulary")
  func openQueryCodesValidateWithoutNarrowingTheProviderVocabulary() throws {
    let station = try CoastalStationIdentifier("9414290")
    let range = try TidesDateRange(
      begin: TidesTimestamp("2025-01-01 00:00").date, end: TidesTimestamp("2025-01-03 00:00").date)
    for code in ["", "\n"] {
      #expect(throws: TidesQueryError.invalidDatum(code)) {
        try ObservedHighLowWaterLevelQuery(
          datum: TideDatum(rawValue: code), range: range, stationIdentifier: station, units: .metric
        )
      }
      #expect(throws: TidesQueryError.invalidUnits(code)) {
        try ObservedHighLowWaterLevelQuery(
          datum: .meanLowerLowWater, range: range, stationIdentifier: station,
          units: TidesUnits(rawValue: code))
      }
    }
    let query = try ObservedHighLowWaterLevelQuery(
      datum: TideDatum(rawValue: "future datum"), range: range, stationIdentifier: station,
      units: TidesUnits(rawValue: "future units"))
    #expect(
      TidesEndpoint.observedHighLowWaterLevels(matching: query).path.contains(
        "datum=future%20datum"))
    #expect(query.units.rawValue == "future units")
  }

  @Test(
    "Recordings preserve observed codes flags and both height units",
    arguments: [Fixture.observedHighLowMetric, .observedHighLowEnglish])
  func recordingsPreserveObservedCodesFlagsAndBothHeightUnits(fixture: Fixture) throws {
    let result = try JSONDecoder().decode(
      ObservedHighLowWaterLevelResponse.self, from: fixture.data())
    #expect(result.observations.count == 8)
    #expect(result.metadata.identifier == "9414290")
    #expect(
      result.observations.first?.height.rawValue
        == (fixture == .observedHighLowMetric ? "-0.35" : "-1.147"))
    #expect(result.observations.first?.time.rawValue == "2025-01-01 02:06")
    #expect(Array(result.observations.prefix(4).map(\.kind.rawValue)) == ["LL", "H ", "L ", "HH"])
    #expect(
      Array(result.observations.prefix(4).map(\.kind.classification)) == [
        .lowerLow, .high, .low, .higherHigh,
      ])
    #expect(result.observations.allSatisfy { $0.flags == "0,0" })
    #expect(
      try JSONDecoder().decode(
        ObservedHighLowWaterLevelResponse.self, from: JSONEncoder().encode(result)) == result)
  }

  @Test(
    "Twelve-month boundaries preserve Gregorian month-end behavior",
    arguments: [
      ["2024-02-29 00:00", "2025-02-28 00:00"],
      ["2025-01-31 12:34", "2026-01-31 12:34"],
    ])
  func twelveMonthBoundariesPreserveGregorianMonthEndBehavior(bounds: [String]) throws {
    let begin = try TidesTimestamp(bounds[0]).date
    let end = try TidesTimestamp(bounds[1]).date
    let station = try CoastalStationIdentifier("9414290")
    let query = try ObservedHighLowWaterLevelQuery(
      datum: .meanLowerLowWater, range: TidesDateRange(begin: begin, end: end),
      stationIdentifier: station, units: .metric)
    #expect(query.range.end == end)
    #expect(throws: TidesQueryError.rangeTooLong(maximumMonths: 12)) {
      try ObservedHighLowWaterLevelQuery(
        datum: .meanLowerLowWater,
        range: TidesDateRange(begin: begin, end: end.addingTimeInterval(60)),
        stationIdentifier: station, units: .metric)
    }
  }
}
