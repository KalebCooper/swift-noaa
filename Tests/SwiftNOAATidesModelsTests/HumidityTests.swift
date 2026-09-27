import Foundation
import SwiftNOAATidesModels
import SwiftNOAATidesTestSupport
import Testing

@Suite("Humidity decoding", .timeLimit(.minutes(suiteTimeLimitMinutes)))
struct HumidityTests {
  @Test("Empty success differs from absent observations")
  func emptySuccessDiffersFromAbsentObservations() throws {
    let body = Data(
      #"{"metadata":{"id":"reported","name":"Reported","lat":"1","lon":"2"},"data":[]}"#.utf8)
    let result = try JSONDecoder().decode(HumidityResponse.self, from: body)
    #expect(result.observations.isEmpty)
    for text in [
      #"{"metadata":{"id":"reported","name":"Reported","lat":"1","lon":"2"}}"#,
      #"{"metadata":{"id":"reported","name":"Reported","lat":"1","lon":"2"},"data":null}"#,
    ] {
      #expect(throws: DecodingError.self) {
        try JSONDecoder().decode(HumidityResponse.self, from: Data(text.utf8))
      }
    }
  }

  @Test("Malformed measurements fail while missing text and zero remain distinct")
  func malformedMeasurementsFailWhileMissingTextAndZeroRemainDistinct() throws {
    for raw in ["", "0", "-1.25"] {
      let body = Data("{\"t\":\"2025-01-01 00:00\",\"v\":\"\(raw)\",\"f\":\"future,flags\"}".utf8)
      let sample = try JSONDecoder().decode(HumidityObservation.self, from: body)
      #expect(sample.humidity.rawValue == raw)
      #expect(sample.humidity.value == Double(raw))
      #expect(sample.flags == "future,flags")
    }
    for value in [#""NaN""#, #""oops""#, "null", "1"] {
      let body = Data("{\"t\":\"2025-01-01 00:00\",\"v\":\(value),\"f\":\"0,0,0\"}".utf8)
      #expect(throws: DecodingError.self) {
        try JSONDecoder().decode(HumidityObservation.self, from: body)
      }
    }
    for text in [
      #"{"v":"1","f":"0,0,0"}"#, #"{"t":"bad","v":"1","f":"0,0,0"}"#,
      #"{"t":"2025-01-01 00:00","v":"1"}"#, #"{"t":"2025-01-01 00:00","f":"0,0,0"}"#,
    ] {
      #expect(throws: DecodingError.self) {
        try JSONDecoder().decode(HumidityObservation.self, from: Data(text.utf8))
      }
    }
  }

  @Test("Recorded missing values retain raw flags")
  func recordedMissingValuesRetainRawFlags() throws {
    let response = try JSONDecoder().decode(
      HumidityResponse.self, from: Fixture.humidityMissing.data())
    let sample = try #require(
      response.observations.first { $0.time.rawValue == "2026-08-19 12:54" })
    #expect(sample.humidity.rawValue == "")
    #expect(sample.humidity.value == nil)
    #expect(sample.flags == "1,1,1")
  }

  @Test(
    "Recordings preserve literal values in both units and cadences",
    arguments: [
      Fixture.humidityMetric, .humidityEnglish, .humidityMetricHourly, .humidityEnglishHourly,
    ])
  func recordingsPreserveLiteralValuesInBothUnitsAndCadences(fixture: Fixture) throws {
    let result = try JSONDecoder().decode(HumidityResponse.self, from: fixture.data())
    #expect(result.metadata.identifier == "8419870")
    #expect(result.observations.count == (fixture.rawValue.contains("hourly") ? 2 : 11))
    let sample = try #require(result.observations.first)
    #expect(sample.humidity.rawValue == (fixture.rawValue.contains("english") ? "37.5" : "37.5"))
    #expect(sample.time.rawValue == "2026-09-26 00:00")
    #expect(sample.flags == "0,0,0")
    #expect(
      try JSONDecoder().decode(HumidityResponse.self, from: JSONEncoder().encode(result)) == result)
  }
}
