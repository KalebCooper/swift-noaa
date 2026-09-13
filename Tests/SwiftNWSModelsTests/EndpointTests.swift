import Foundation
import SwiftNWSModels
import SwiftNWSTestSupport
import Testing

@Suite("Endpoint", .timeLimit(.minutes(suiteTimeLimitMinutes)))
struct EndpointTests {
  @Test(
    "A link anywhere else is refused",
    arguments: [
      "https://example.com/gridpoints/EWX/156,91/stations",
      "https://api.weather.gov.example.com/gridpoints/EWX/156,91/stations",
      "http://api.weather.gov/gridpoints/EWX/156,91/stations",
      "https://api.weather.gov:444/stations",
      "https://user@api.weather.gov/stations",
      "https://api.weather.gov/stations#fragment",
    ])
  func aLinkAnywhereElseIsRefused(link: String) throws {
    let url = try #require(URL(string: link))

    #expect(Endpoint<FeatureCollection<ObservationStation>>(link: url) == nil)
  }

  @Test("A link on the API becomes its path")
  func aLinkOnTheAPIBecomesItsPath() throws {
    let link = try #require(URL(string: "https://api.weather.gov/gridpoints/EWX/156,91/stations"))

    let endpoint = Endpoint<FeatureCollection<ObservationStation>>(link: link)

    #expect(endpoint?.path == "/gridpoints/EWX/156,91/stations")
  }

  @Test("A same-origin link retains its encoded path and query")
  func aSameOriginLinkRetainsItsEncodedPathAndQuery() throws {
    let link = try #require(URL(string: "https://API.WEATHER.GOV:443/stations/A%2FB?cursor=a%2Bb"))
    #expect(
      Endpoint<FeatureCollection<ObservationStation>>(link: link)?.path
        == "/stations/A%2FB?cursor=a%2Bb")
  }

  @Test("latestObservation(stationIdentifier:) names the station's latest observation")
  func latestObservationNamesTheStationsLatestObservation() {
    #expect(
      Endpoint.latestObservation(stationIdentifier: "KATT").path
        == "/stations/KATT/observations/latest")
  }

  @Test("observationStations(near:) follows the point's link")
  func observationStationsFollowsThePointsLink() throws {
    let point = try JSONDecoder().decode(Feature<Point>.self, from: Fixture.point.data())

    #expect(
      Endpoint.observationStations(near: point.properties)?.path
        == "/gridpoints/EWX/156,91/stations")
  }

  @Test(
    "point(for:) writes each coordinate to at most four decimal places",
    arguments: [
      (30.26721234, -97.74309999, "/points/30.2672,-97.7431"),
      (40, -100, "/points/40,-100"),
      (1.00051, -0.05, "/points/1.0005,-0.05"),
      (-0.00004, 0.00004, "/points/0,0"),
    ])
  func pointWritesEachCoordinateToAtMostFourDecimalPlaces(
    latitude: Double, longitude: Double, path: String
  ) throws {
    let location = try WeatherCoordinate(latitude: latitude, longitude: longitude)
    let endpoint = Endpoint.point(for: location)

    #expect(endpoint.path == path)
    #expect(endpoint.accept == .geoJSON)
  }

  @Test("Station identifiers occupy exactly one path segment")
  func stationIdentifiersOccupyExactlyOnePathSegment() {
    #expect(
      Endpoint.latestObservation(stationIdentifier: "../A/B?x=#%\n").path
        == "/stations/%2E%2E%2FA%2FB%3Fx%3D%23%25%0A/observations/latest")
  }
}
