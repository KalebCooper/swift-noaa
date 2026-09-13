import Foundation
import SwiftNWSModels
import SwiftNWSTestSupport
import Testing

@Suite("Endpoint", .timeLimit(.minutes(suiteTimeLimitMinutes)))
struct EndpointTests {
  @Test(
    "point(latitude:longitude:) writes each coordinate to at most four decimal places",
    arguments: [
      (30.26721234, -97.74309999, "/points/30.2672,-97.7431"),
      (40, -100, "/points/40,-100"),
      (1.00051, -0.05, "/points/1.0005,-0.05"),
      (-0.00004, 0.00004, "/points/0,0"),
    ])
  func pointWritesEachCoordinateToAtMostFourDecimalPlaces(
    latitude: Double, longitude: Double, path: String
  ) {
    let endpoint = Endpoint.point(latitude: latitude, longitude: longitude)

    #expect(endpoint.path == path)
    #expect(endpoint.accept == .geoJSON)
  }

  @Test("latestObservation(stationIdentifier:) names the station's latest observation")
  func latestObservationNamesTheStationsLatestObservation() {
    #expect(
      Endpoint.latestObservation(stationIdentifier: "KATT").path
        == "/stations/KATT/observations/latest")
  }

  @Test("A link on the API becomes its path")
  func aLinkOnTheAPIBecomesItsPath() throws {
    let link = try #require(URL(string: "https://api.weather.gov/gridpoints/EWX/156,91/stations"))

    let endpoint = Endpoint<FeatureCollection<ObservationStation>>(link: link)

    #expect(endpoint?.path == "/gridpoints/EWX/156,91/stations")
  }

  @Test(
    "A link anywhere else is refused",
    arguments: [
      "https://example.com/gridpoints/EWX/156,91/stations",
      "https://api.weather.gov.example.com/gridpoints/EWX/156,91/stations",
      "http://api.weather.gov/gridpoints/EWX/156,91/stations",
    ])
  func aLinkAnywhereElseIsRefused(link: String) throws {
    let url = try #require(URL(string: link))

    #expect(Endpoint<FeatureCollection<ObservationStation>>(link: url) == nil)
  }

  @Test("observationStations(near:) follows the point's link")
  func observationStationsFollowsThePointsLink() throws {
    let point = try JSONDecoder().decode(Feature<Point>.self, from: Fixture.point.data())

    #expect(
      Endpoint.observationStations(near: point.properties)?.path
        == "/gridpoints/EWX/156,91/stations")
  }
}
