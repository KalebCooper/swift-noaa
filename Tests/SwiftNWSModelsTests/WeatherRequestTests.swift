import SwiftNWSModels
import SwiftNWSTestSupport
import Testing

@Suite("WeatherRequest", .timeLimit(.minutes(suiteTimeLimitMinutes)))
struct WeatherRequestTests {
  @Test("A custom request exposes its endpoint without an SDK import")
  func aCustomRequestExposesItsEndpointWithoutAnSDKImport() throws {
    let endpoint = try #require(Endpoint<String>(path: "/custom"))
    let request = WeatherRequest(endpoint: endpoint)
    guard case .endpoint(let actual) = request.resolution else {
      Issue.record("Expected a direct endpoint")
      return
    }
    #expect(actual == endpoint)
  }

  @Test("A grid request describes its coordinate without I/O")
  func aGridRequestDescribesItsCoordinateWithoutIO() throws {
    let home = try WeatherCoordinate(latitude: 30.26721, longitude: -97.74306)
    let request = WeatherRequest.forecastGrid(for: home)
    guard case .forecastGrid(let location) = request.resolution else {
      Issue.record("Expected a grid resolution")
      return
    }
    #expect(location == home)
  }

  @Test("Equal grid requests are equal and hash alike")
  func equalGridRequestsAreEqualAndHashAlike() throws {
    let home = try WeatherCoordinate(latitude: 30.2672, longitude: -97.7431)
    let other = try WeatherCoordinate(latitude: 35.0844, longitude: -106.6504)
    let requests: Set<WeatherRequest<ForecastGrid>> = [
      .forecastGrid(for: home), .forecastGrid(for: home), .forecastGrid(for: other),
    ]
    #expect(requests.count == 2)
    #expect(WeatherRequest.forecastGrid(for: home) != .forecastGrid(for: other))
  }

  @Test("A nearby station request describes its coordinate without I/O")
  func aNearbyStationRequestDescribesItsCoordinateWithoutIO() throws {
    let home = try WeatherCoordinate(latitude: 30.26721, longitude: -97.74306)
    let request = WeatherRequest.observationStations(near: home)
    guard case .nearbyObservationStations(let location) = request.resolution else {
      Issue.record("Expected a nearby-station resolution")
      return
    }
    #expect(location == home)
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
