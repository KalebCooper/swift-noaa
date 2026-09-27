import Foundation
import SwiftNOAATidesModels
import SwiftNOAATidesTestSupport
import Testing

@Suite("Flood thresholds", .timeLimit(.minutes(suiteTimeLimitMinutes)))
struct CoastalFloodLevelsTests {
  @Test("Agency families and action are independently reported")
  func agencyFamiliesAndActionAreIndependentlyReported() throws {
    let full = try JSONDecoder().decode(
      CoastalFloodLevels.self, from: Fixture.floodlevels8638610.data())
    #expect(full.actionLevel == 2.555)
    #expect(full.nosMajor == 3.380)
    #expect(full.nosMinor == 2.710)
    #expect(full.nosModerate == 3.001)
    #expect(full.nwsMajor == 3.317)
    #expect(full.nwsMinor == 2.708)
    #expect(full.nwsModerate == 3.012)
    let partial = try JSONDecoder().decode(
      CoastalFloodLevels.self, from: Fixture.floodlevels8419870.data())
    #expect(partial.nosMajor == nil)
    #expect(partial.nosMinor == nil)
    #expect(partial.nosModerate == nil)
    #expect(partial.nwsMajor == 4.653)
    #expect(partial.nwsMinor == 4.044)
    #expect(partial.nwsModerate == 4.349)
    #expect(partial.actionLevel == 3.765)
  }

  @Test("Constructed zero negative and sentinel-like numbers are not normalized")
  func constructedZeroNegativeAndSentinelLikeNumbersAreNotNormalized() throws {
    var object = try #require(
      JSONSerialization.jsonObject(with: Fixture.floodlevelsMetric.data()) as? [String: Any])
    object["nos_minor"] = 0
    object["nos_moderate"] = -1.5
    object["nos_major"] = -99999
    let result = try JSONDecoder().decode(
      CoastalFloodLevels.self, from: JSONSerialization.data(withJSONObject: object))
    #expect(result.nosMinor == 0)
    #expect(result.nosModerate == -1.5)
    #expect(result.nosMajor == -99999)
  }

  @Test("Required nullable fields reject absent or malformed values")
  func requiredNullableFieldsRejectAbsentOrMalformedValues() throws {
    let original = try #require(
      JSONSerialization.jsonObject(with: Fixture.floodlevelsMetric.data()) as? [String: Any])
    for key in [
      "action", "nos_major", "nos_minor", "nos_moderate", "nws_major", "nws_minor", "nws_moderate",
    ] {
      var missing = original
      missing.removeValue(forKey: key)
      #expect(throws: DecodingError.self) {
        try JSONDecoder().decode(
          CoastalFloodLevels.self, from: JSONSerialization.data(withJSONObject: missing))
      }
      for value: Any in ["NaN", "1.0", true] {
        var malformed = original
        malformed[key] = value
        #expect(throws: DecodingError.self) {
          try JSONDecoder().decode(
            CoastalFloodLevels.self, from: JSONSerialization.data(withJSONObject: malformed))
        }
      }
    }
  }

  @Test(
    "Unit recordings retain literal thresholds and explicit nulls",
    arguments: [Fixture.floodlevelsMetric, .floodlevelsEnglish])
  func unitRecordingsRetainLiteralThresholdsAndExplicitNulls(fixture: Fixture) throws {
    let result = try JSONDecoder().decode(CoastalFloodLevels.self, from: fixture.data())
    let metric = fixture == .floodlevelsMetric
    #expect(result.nosMinor == (metric ? 4.173 : 13.69))
    #expect(result.nosModerate == (metric ? 4.455 : 14.62))
    #expect(result.nosMajor == (metric ? 4.843 : 15.89))
    #expect(result.nwsMinor == (metric ? 3.968 : 13.02))
    #expect(result.nwsModerate == nil)
    #expect(result.nwsMajor == nil)
    #expect(result.actionLevel == nil)
    #expect(
      result.selfLink
        == "https://api.tidesandcurrents.noaa.gov/mdapi/prod/webapi/stations/9414290/floodlevels.json"
    )
    let encoded = try JSONEncoder().encode(result)
    #expect(try JSONDecoder().decode(CoastalFloodLevels.self, from: encoded) == result)
    let fields = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
    #expect(fields["action"] is NSNull)
    #expect(fields["datum"] == nil)
    #expect(fields["units"] == nil)
  }
}
