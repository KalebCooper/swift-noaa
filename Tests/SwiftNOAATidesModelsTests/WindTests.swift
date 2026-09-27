import Foundation
import SwiftNOAATidesModels
import SwiftNOAATidesTestSupport
import Testing

@Suite("Wind decoding", .timeLimit(.minutes(suiteTimeLimitMinutes)))
struct WindTests {
  @Test("Components retain independent missing values and direction boundaries")
  func componentsRetainIndependentMissingValuesAndDirectionBoundaries() throws {
    for direction in ["", "0", "360", "-1", "361"] {
      let body =
        Data(#"{"t":"2025-01-01 00:00","s":"","d":""#.utf8)
        + Data(direction.utf8) + Data(#"","dr":"unfamiliar","g":"0","f":"future"}"#.utf8)
      let sample = try JSONDecoder().decode(WindObservation.self, from: body)
      #expect(sample.speed.value == nil)
      #expect(sample.gust.value == 0)
      #expect(sample.numericDirection.rawValue == direction)
      #expect(sample.textDirection == "unfamiliar")
      #expect(sample.flags == "future")
    }
    for key in ["s", "d", "g"] {
      var body = Self.sample
      body[key] = ""
      let sample = try JSONDecoder().decode(
        WindObservation.self, from: JSONSerialization.data(withJSONObject: body))
      #expect(sample.speed.rawValue == (key == "s" ? "" : "0.0"))
      #expect(sample.gust.rawValue == (key == "g" ? "" : "1.5"))
      #expect(sample.numericDirection.rawValue == (key == "d" ? "" : "360"))
    }
  }

  @Test("Empty success differs from absent observations")
  func emptySuccessDiffersFromAbsentObservations() throws {
    let body = Data(
      #"{"metadata":{"id":"reported","name":"Reported","lat":"1","lon":"2"},"data":[]}"#.utf8)
    #expect(try JSONDecoder().decode(WindResponse.self, from: body).observations.isEmpty)
    for raw in [
      #"{"metadata":{"id":"reported","name":"Reported","lat":"1","lon":"2"}}"#,
      #"{"metadata":{"id":"reported","name":"Reported","lat":"1","lon":"2"},"data":null}"#,
    ] {
      #expect(throws: DecodingError.self) {
        try JSONDecoder().decode(WindResponse.self, from: Data(raw.utf8))
      }
    }
  }

  @Test("Malformed and absent components fail without substituting other components")
  func malformedAndAbsentComponentsFailWithoutSubstitutingOtherComponents() throws {
    for key in ["s", "d", "g"] {
      for value: Any in ["NaN", "infinity", "bad", NSNull(), 1] {
        var body = Self.sample
        body[key] = value
        let data = try JSONSerialization.data(withJSONObject: body)
        #expect(throws: DecodingError.self) {
          try JSONDecoder().decode(WindObservation.self, from: data)
        }
      }
    }
    for key in ["s", "d", "dr", "g", "f", "t"] {
      var body = Self.sample
      body.removeValue(forKey: key)
      let data = try JSONSerialization.data(withJSONObject: body)
      #expect(throws: DecodingError.self) {
        try JSONDecoder().decode(WindObservation.self, from: data)
      }
    }
    var body = Self.sample
    body["t"] = "2025-02-30 00:00"
    #expect(throws: DecodingError.self) {
      try JSONDecoder().decode(
        WindObservation.self, from: JSONSerialization.data(withJSONObject: body))
    }
  }

  @Test("Recorded missing components do not imply calm")
  func recordedMissingComponentsDoNotImplyCalm() throws {
    let result = try JSONDecoder().decode(WindResponse.self, from: Fixture.windMissing.data())
    let sample = try #require(result.observations.first { $0.time.rawValue == "2026-08-05 05:48" })
    #expect(sample.speed.rawValue == "")
    #expect(sample.gust.rawValue == "")
    #expect(sample.numericDirection.rawValue == "")
    #expect(sample.textDirection == "")
    #expect(sample.flags == "1,1")
    #expect(sample.speed.value == nil)
    #expect(sample.gust.value == nil)
    #expect(sample.numericDirection.value == nil)
  }

  @Test("Recorded zero speed retains reported gust and direction")
  func recordedZeroSpeedRetainsReportedGustAndDirection() throws {
    let result = try JSONDecoder().decode(WindResponse.self, from: Fixture.windZero.data())
    let sample = try #require(result.observations.first { $0.time.rawValue == "2026-08-11 17:18" })
    #expect(sample.speed.rawValue == "0.0")
    #expect(sample.speed.value == 0)
    #expect(sample.gust.rawValue == "0.8")
    #expect(sample.numericDirection.rawValue == "204.0")
    #expect(sample.textDirection == "SSW")
  }

  @Test(
    "Recordings preserve both unit systems and cadences",
    arguments: [Fixture.windMetric, .windEnglish, .windMetricHourly, .windEnglishHourly])
  func recordingsPreserveBothUnitSystemsAndCadences(fixture: Fixture) throws {
    let result = try JSONDecoder().decode(WindResponse.self, from: fixture.data())
    let english = fixture.rawValue.contains("english")
    #expect(result.metadata.identifier == "9414290")
    #expect(result.observations.count == (fixture.rawValue.contains("hourly") ? 2 : 11))
    let sample = try #require(result.observations.first)
    #expect(sample.speed.rawValue == (english ? "2.14" : "1.1"))
    #expect(sample.gust.rawValue == (english ? "2.53" : "1.3"))
    #expect(sample.numericDirection.rawValue == "270.0")
    #expect(sample.textDirection == "W")
    #expect(sample.flags == "0,0")
    #expect(sample.time.rawValue == "2025-01-01 00:00")
    #expect(
      try JSONDecoder().decode(WindResponse.self, from: JSONEncoder().encode(result)) == result)
  }

  private static var sample: [String: Any] {
    ["t": "2025-01-01 00:00", "s": "0.0", "d": "360", "dr": "N", "g": "1.5", "f": "0,0"]
  }
}
