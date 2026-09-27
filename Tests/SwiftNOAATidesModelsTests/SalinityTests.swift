import Foundation
import SwiftNOAATidesModels
import SwiftNOAATidesTestSupport
import Testing

@Suite("Salinity decoding", .timeLimit(.minutes(suiteTimeLimitMinutes)))
struct SalinityTests {
  @Test("Each quantity preserves missing and zero independently")
  func eachQuantityPreservesMissingAndZeroIndependently() throws {
    for salinity in ["", "0", "-1.25"] {
      for gravity in ["", "0", "1.022"] {
        let body = ["t": "2025-01-01 00:00", "s": salinity, "g": gravity]
        let sample = try JSONDecoder().decode(
          SalinityObservation.self, from: JSONSerialization.data(withJSONObject: body))
        #expect(sample.salinity.rawValue == salinity)
        #expect(sample.salinity.value == Double(salinity))
        #expect(sample.specificGravity.rawValue == gravity)
        #expect(sample.specificGravity.value == Double(gravity))
      }
    }
  }

  @Test("Empty success differs from absent observations")
  func emptySuccessDiffersFromAbsentObservations() throws {
    let body = Data(
      #"{"metadata":{"id":"reported","name":"Reported","lat":"1","lon":"2"},"data":[]}"#.utf8)
    #expect(try JSONDecoder().decode(SalinityResponse.self, from: body).observations.isEmpty)
    for raw in [
      #"{"metadata":{"id":"reported","name":"Reported","lat":"1","lon":"2"}}"#,
      #"{"metadata":{"id":"reported","name":"Reported","lat":"1","lon":"2"},"data":null}"#,
    ] {
      #expect(throws: DecodingError.self) {
        try JSONDecoder().decode(SalinityResponse.self, from: Data(raw.utf8))
      }
    }
  }

  @Test("Malformed and absent quantities fail independently")
  func malformedAndAbsentQuantitiesFailIndependently() throws {
    for key in ["s", "g"] {
      for value: Any in ["NaN", "bad", NSNull(), 1] {
        var body: [String: Any] = ["t": "2025-01-01 00:00", "s": "26.38", "g": "1.022"]
        body[key] = value
        let data = try JSONSerialization.data(withJSONObject: body)
        #expect(throws: DecodingError.self) {
          try JSONDecoder().decode(SalinityObservation.self, from: data)
        }
      }
    }
    for key in ["s", "g", "t"] {
      var body = ["t": "2025-01-01 00:00", "s": "26.38", "g": "1.022"]
      body.removeValue(forKey: key)
      let data = try JSONSerialization.data(withJSONObject: body)
      #expect(throws: DecodingError.self) {
        try JSONDecoder().decode(SalinityObservation.self, from: data)
      }
    }
    #expect(throws: DecodingError.self) {
      try JSONDecoder().decode(
        SalinityObservation.self, from: Data(#"{"t":"bad","s":"1","g":"1"}"#.utf8))
    }
  }

  @Test("Recorded missing quantities stay missing")
  func recordedMissingQuantitiesStayMissing() throws {
    let result = try JSONDecoder().decode(
      SalinityResponse.self, from: Fixture.salinityMissing.data())
    let sample = try #require(result.observations.first { $0.time.rawValue == "2026-08-19 12:54" })
    #expect(sample.salinity.rawValue == "")
    #expect(sample.salinity.value == nil)
    #expect(sample.specificGravity.rawValue == "")
    #expect(sample.specificGravity.value == nil)
  }

  @Test(
    "Recordings preserve salinity and specific gravity in both units and cadences",
    arguments: [
      Fixture.salinityMetric, .salinityEnglish, .salinityMetricHourly, .salinityEnglishHourly,
    ])
  func recordingsPreserveSalinityAndSpecificGravityInBothUnitsAndCadences(fixture: Fixture) throws {
    let result = try JSONDecoder().decode(SalinityResponse.self, from: fixture.data())
    #expect(result.metadata.identifier == "8419870")
    #expect(result.observations.count == (fixture.rawValue.contains("hourly") ? 2 : 11))
    let sample = try #require(result.observations.first)
    #expect(sample.salinity.rawValue == "26.38")
    #expect(sample.specificGravity.rawValue == "1.022")
    #expect(sample.time.rawValue == "2025-01-01 00:00")
    #expect(
      try JSONDecoder().decode(SalinityResponse.self, from: JSONEncoder().encode(result)) == result)
  }
}
