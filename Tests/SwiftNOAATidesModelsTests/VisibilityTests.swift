import Foundation
import SwiftNOAATidesModels
import SwiftNOAATidesTestSupport
import Testing

@Suite("Visibility decoding", .timeLimit(.minutes(suiteTimeLimitMinutes)))
struct VisibilityTests {
  @Test("Empty success differs from absent observations")
  func emptySuccessDiffersFromAbsentObservations() throws {
    let body = Data(
      #"{"metadata":{"id":"reported","name":"Reported","lat":"1","lon":"2"},"data":[]}"#.utf8)
    let result = try JSONDecoder().decode(VisibilityResponse.self, from: body)
    #expect(result.observations.isEmpty)
    for text in [
      #"{"metadata":{"id":"reported","name":"Reported","lat":"1","lon":"2"}}"#,
      #"{"metadata":{"id":"reported","name":"Reported","lat":"1","lon":"2"},"data":null}"#,
    ] {
      #expect(throws: DecodingError.self) {
        try JSONDecoder().decode(VisibilityResponse.self, from: Data(text.utf8))
      }
    }
  }

  @Test("Malformed measurements fail while missing text and zero remain distinct")
  func malformedMeasurementsFailWhileMissingTextAndZeroRemainDistinct() throws {
    for raw in ["", "0", "-1.25"] {
      let body = Data("{\"t\":\"2025-01-01 00:00\",\"v\":\"\(raw)\",\"f\":\"future,flags\"}".utf8)
      let sample = try JSONDecoder().decode(VisibilityObservation.self, from: body)
      #expect(sample.visibility.rawValue == raw)
      #expect(sample.visibility.value == Double(raw))
      #expect(sample.flags == "future,flags")
    }
    for value in [#""NaN""#, #""oops""#, "null", "1"] {
      let body = Data("{\"t\":\"2025-01-01 00:00\",\"v\":\(value),\"f\":\"0,0,0\"}".utf8)
      #expect(throws: DecodingError.self) {
        try JSONDecoder().decode(VisibilityObservation.self, from: body)
      }
    }
    for text in [
      #"{"v":"1","f":"0,0,0"}"#, #"{"t":"bad","v":"1","f":"0,0,0"}"#,
      #"{"t":"2025-01-01 00:00","v":"1"}"#, #"{"t":"2025-01-01 00:00","f":"0,0,0"}"#,
    ] {
      #expect(throws: DecodingError.self) {
        try JSONDecoder().decode(VisibilityObservation.self, from: Data(text.utf8))
      }
    }
  }

  @Test("Recorded missing values retain raw flags")
  func recordedMissingValuesRetainRawFlags() throws {
    let response = try JSONDecoder().decode(
      VisibilityResponse.self, from: Fixture.visibilityMissing.data())
    let sample = try #require(
      response.observations.first { $0.time.rawValue == "2026-08-01 11:42" })
    #expect(sample.visibility.rawValue == "")
    #expect(sample.visibility.value == nil)
    #expect(sample.flags == "1,1,1")
  }

  @Test(
    "Recordings preserve literal values in both units and cadences",
    arguments: [
      Fixture.visibilityMetric, .visibilityEnglish, .visibilityMetricHourly,
      .visibilityEnglishHourly,
    ])
  func recordingsPreserveLiteralValuesInBothUnitsAndCadences(fixture: Fixture) throws {
    let result = try JSONDecoder().decode(VisibilityResponse.self, from: fixture.data())
    #expect(result.metadata.identifier == "9414296")
    #expect(result.observations.count == (fixture.rawValue.contains("hourly") ? 2 : 11))
    let sample = try #require(result.observations.first)
    #expect(sample.visibility.rawValue == (fixture.rawValue.contains("english") ? "5.4" : "10.0"))
    #expect(sample.time.rawValue == "2026-09-26 00:00")
    #expect(sample.flags == "0,0,0")
    #expect(
      try JSONDecoder().decode(VisibilityResponse.self, from: JSONEncoder().encode(result))
        == result)
  }
}
