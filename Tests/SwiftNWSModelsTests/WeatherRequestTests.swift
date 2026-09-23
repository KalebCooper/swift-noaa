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

  @Test("Zone forecast, observation, and station requests expose their resolutions without I/O")
  func zoneForecastObservationAndStationRequestsExposeTheirResolutionsWithoutIO() throws {
    let forecast = WeatherRequest.zoneForecast(identifier: "TXZ192", type: .forecast)
    #expect(forecast.resolution == .zoneForecast(identifier: "TXZ192", type: .forecast))
    #expect(forecast == .zoneForecast(identifier: "TXZ192", type: AppZoneType.forecast))
    #expect(Set([forecast, .zoneForecast(identifier: "TXZ192", type: .forecast)]).count == 1)

    let query = try ZoneObservationQuery(limit: 2, zoneIdentifier: "TXZ192")
    let observations = WeatherRequest.observations(inForecastZone: query)
    #expect(observations.resolution == .endpoint(.observations(inForecastZone: query)))
    #expect(
      observations != .observations(matching: try ObservationQuery(stationIdentifier: "KATT")))

    let stations = WeatherRequest.observationStations(inForecastZone: "TXZ192")
    #expect(stations.resolution == .forecastZoneStations(identifier: "TXZ192"))
    #expect(stations != .observationStations(matching: try ObservationStationQuery()))

    let unusable = WeatherRequest.observationStations(inForecastZone: "")
    #expect(unusable.resolution == .forecastZoneStations(identifier: ""))
  }

  @Test("Zone requests expose their resolutions without I/O")
  func zoneRequestsExposeTheirResolutionsWithoutIO() throws {
    let query = try ZoneQuery(areas: [.texas], limit: 2)
    let stored = WeatherRequest.zones(matching: query, types: [.county, .fire])
    #expect(stored.resolution == .endpoint(.zones(matching: query, types: [.county, .fire])))

    let typed = WeatherRequest.zones(matching: query, ofType: .forecast)
    #expect(typed.resolution == .zonesOfType(query: query, type: .forecast))
    #expect(typed == .zones(matching: query, ofType: AppZoneType.forecast))

    let detail = WeatherRequest.zone(identifier: "TXZ192", type: .forecast)
    #expect(detail.resolution == .zone(identifier: "TXZ192", type: .forecast, effective: nil))
    #expect(detail == .zone(identifier: "TXZ192", type: AppZoneType.forecast))
    #expect(Set([detail, .zone(identifier: "TXZ192", type: .forecast)]).count == 1)

    // An unusable type or identifier is a request value; only execution rejects it.
    let unusable = WeatherRequest.zone(identifier: "", type: ZoneType(rawValue: ""))
    #expect(
      unusable.resolution == .zone(identifier: "", type: ZoneType(rawValue: ""), effective: nil))
  }
}

private enum AppZoneType: String {
  case forecast
}
