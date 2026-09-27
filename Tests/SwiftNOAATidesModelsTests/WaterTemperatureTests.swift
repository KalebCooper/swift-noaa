import Foundation
import SwiftNOAATidesModels
import SwiftNOAATidesTestSupport
import Testing

@Suite("WaterTemperature decoding", .timeLimit(.minutes(suiteTimeLimitMinutes)))
struct WaterTemperatureTests {
  @Test("Empty success differs from absent observations")
  func emptySuccessDiffersFromAbsentObservations() throws {
    let body = Data(
      #"{"metadata":{"id":"reported","name":"Reported","lat":"1","lon":"2"},"data":[]}"#.utf8)
    let result = try JSONDecoder().decode(WaterTemperatureResponse.self, from: body)
    #expect(result.observations.isEmpty)
    for text in [
      #"{"metadata":{"id":"reported","name":"Reported","lat":"1","lon":"2"}}"#,
      #"{"metadata":{"id":"reported","name":"Reported","lat":"1","lon":"2"},"data":null}"#,
    ] {
      #expect(throws: DecodingError.self) {
        try JSONDecoder().decode(WaterTemperatureResponse.self, from: Data(text.utf8))
      }
    }
  }

  @Test("Malformed measurements fail while missing text and zero remain distinct")
  func malformedMeasurementsFailWhileMissingTextAndZeroRemainDistinct() throws {
    for raw in ["", "0", "-1.25"] {
      let body = Data("{\"t\":\"2025-01-01 00:00\",\"v\":\"\(raw)\",\"f\":\"future,flags\"}".utf8)
      let sample = try JSONDecoder().decode(WaterTemperatureObservation.self, from: body)
      #expect(sample.temperature.rawValue == raw)
      #expect(sample.temperature.value == Double(raw))
      #expect(sample.flags == "future,flags")
    }
    for value in [#""NaN""#, #""oops""#, "null", "1"] {
      let body = Data("{\"t\":\"2025-01-01 00:00\",\"v\":\(value),\"f\":\"0,0,0\"}".utf8)
      #expect(throws: DecodingError.self) {
        try JSONDecoder().decode(WaterTemperatureObservation.self, from: body)
      }
    }
    for text in [
      #"{"v":"1","f":"0,0,0"}"#, #"{"t":"bad","v":"1","f":"0,0,0"}"#,
      #"{"t":"2025-01-01 00:00","v":"1"}"#, #"{"t":"2025-01-01 00:00","f":"0,0,0"}"#,
    ] {
      #expect(throws: DecodingError.self) {
        try JSONDecoder().decode(WaterTemperatureObservation.self, from: Data(text.utf8))
      }
    }
  }

  @Test("Recorded missing temperature remains distinct from zero")
  func recordedMissingTemperatureRemainsDistinctFromZero() throws {
    let result = try JSONDecoder().decode(
      WaterTemperatureResponse.self, from: Fixture.waterTemperatureMissing.data())
    let missing = try #require(result.observations.first { $0.time.rawValue == "2024-02-12 11:18" })
    #expect(missing.temperature.rawValue == "")
    #expect(missing.temperature.value == nil)
    #expect(missing.flags == "1,1,1")
  }

  @Test(
    "Recordings preserve literal values in both units and cadences",
    arguments: [
      Fixture.waterTemperatureMetric, .waterTemperatureEnglish, .waterTemperatureMetricHourly,
      .waterTemperatureEnglishHourly,
    ])
  func recordingsPreserveLiteralValuesInBothUnitsAndCadences(fixture: Fixture) throws {
    let result = try JSONDecoder().decode(WaterTemperatureResponse.self, from: fixture.data())
    #expect(result.metadata.identifier == "1611400")
    #expect(result.observations.count == (fixture.rawValue.contains("hourly") ? 2 : 11))
    let sample = try #require(result.observations.first)
    #expect(sample.temperature.rawValue == (fixture.rawValue.contains("english") ? "77.5" : "25.3"))
    #expect(sample.time.rawValue == "2025-01-01 00:00")
    #expect(sample.flags == "0,0,0")
    #expect(
      try JSONDecoder().decode(WaterTemperatureResponse.self, from: JSONEncoder().encode(result))
        == result)
  }
}
