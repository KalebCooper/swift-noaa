import SwiftNWSModels
import Testing

@Suite("MediaType", .timeLimit(.minutes(suiteTimeLimitMinutes)))
struct MediaTypeTests {
  @Test("geoJSON is written as application/geo+json")
  func geoJSONIsWrittenAsApplicationGeoJSON() {
    #expect(MediaType.geoJSON.rawValue == "application/geo+json")
  }

  @Test("Two media types with the same string are equal")
  func twoMediaTypesWithTheSameStringAreEqual() {
    #expect(MediaType(rawValue: "application/geo+json") == .geoJSON)
    #expect(MediaType(rawValue: "application/ld+json") != .geoJSON)
  }
}
