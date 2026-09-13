import SwiftNWSModels
import SwiftNWSTestSupport
import Testing

@Suite("WeatherRequest", .timeLimit(.minutes(suiteTimeLimitMinutes)))
struct WeatherRequestTests {
  @Test("A custom request exposes its endpoint without an SDK import")
  func aCustomRequestExposesItsEndpointWithoutAnSDKImport() {
    let endpoint = Endpoint<String>(path: "/custom")
    let request = WeatherRequest(endpoint: endpoint)
    guard case .endpoint(let actual) = request.resolution else {
      Issue.record("Expected a direct endpoint")
      return
    }
    #expect(actual == endpoint)
  }

  @Test("A nearest observation exposes its normalized coordinate")
  func aNearestObservationExposesItsNormalizedCoordinate() throws {
    let home = try WeatherCoordinate(latitude: 30.26721, longitude: -97.74306)
    let request = WeatherRequest.latestObservation(from: .nearest(to: home))
    guard case .latestObservation(.nearest(let actual)) = request.resolution else {
      Issue.record("Expected coordinate resolution")
      return
    }
    #expect(actual.latitude == 30.2672)
    #expect(actual.longitude == -97.7431)
  }

  @Test("A station observation exposes its open identifier")
  func aStationObservationExposesItsOpenIdentifier() {
    let request = WeatherRequest.latestObservation(from: .station("FUTURE-STATION"))
    guard case .latestObservation(.station(let identifier)) = request.resolution else {
      Issue.record("Expected station resolution")
      return
    }
    #expect(identifier == "FUTURE-STATION")
    #expect(request == .latestObservation(from: .station("FUTURE-STATION")))
  }
}
