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

  @Test("A grid data link from another origin is refused")
  func aGridDataLinkFromAnotherOriginIsRefused() throws {
    var point = try JSONDecoder().decode(Feature<Point>.self, from: Fixture.point.data()).properties
    point.forecastGridData = try #require(URL(string: "https://example.com/gridpoints/EWX/156,91"))
    #expect(Endpoint.forecastGrid(for: point) == nil)
  }

  @Test("A grid data link keeps its encoded query")
  func aGridDataLinkKeepsItsEncodedQuery() throws {
    var point = try JSONDecoder().decode(Feature<Point>.self, from: Fixture.point.data()).properties
    point.forecastGridData = try #require(
      URL(string: "https://api.weather.gov/gridpoints/EWX/156,91?future=a%2Bb"))
    #expect(Endpoint.forecastGrid(for: point)?.path == "/gridpoints/EWX/156,91?future=a%2Bb")
  }

  @Test("The grid endpoint follows the point's grid data link")
  func theGridEndpointFollowsThePointsGridDataLink() throws {
    let point = try JSONDecoder().decode(Feature<Point>.self, from: Fixture.point.data())
    let endpoint = try #require(Endpoint.forecastGrid(for: point.properties))
    #expect(endpoint.path == "/gridpoints/EWX/156,91")
    #expect(endpoint.accept == .geoJSON)
    #expect(endpoint.featureFlags.isEmpty)
  }

  @Test("latestObservation(stationIdentifier:) names the station's latest observation")
  func latestObservationNamesTheStationsLatestObservation() throws {
    #expect(
      try #require(Endpoint.latestObservation(stationIdentifier: "KATT")).path
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
  func stationIdentifiersOccupyExactlyOnePathSegment() throws {
    #expect(
      try #require(Endpoint.latestObservation(stationIdentifier: "A/B?x=#%")).path
        == "/stations/A%2FB%3Fx%3D%23%25/observations/latest")
  }

  @Test("Zone routes name exact paths and ask for GeoJSON without feature flags")
  func zoneRoutesNameExactPathsAndAskForGeoJSONWithoutFeatureFlags() throws {
    let query = try ZoneQuery(areas: [.texas], limit: 2)
    let root = Endpoint.zones(matching: query)
    let typed = try #require(Endpoint.zones(matching: query, ofType: .forecast))
    let detail = try #require(Endpoint.zone(identifier: "TXZ192", type: .forecast))
    #expect(root.path == "/zones?area=TX&limit=2")
    #expect(typed.path == "/zones/forecast?area=TX&limit=2")
    #expect(detail.path == "/zones/forecast/TXZ192")
    for endpoint in [root, typed] {
      #expect(endpoint.accept == .geoJSON)
      #expect(endpoint.featureFlags.isEmpty)
    }
    #expect(detail.accept == .geoJSON)
    #expect(detail.featureFlags.isEmpty)
    // 2026-09-20T00:00:00.5Z, sent with whole-second precision.
    let effective = Date(timeIntervalSince1970: 1_789_862_400.5)
    #expect(
      Endpoint.zone(effective: effective, identifier: "TXZ192", type: .county)?.path
        == "/zones/county/TXZ192?effective=2026-09-20T00:00:00Z")
  }

  @Test("Zone forecast, observation, and station routes name exact paths and ask for GeoJSON")
  func zoneForecastObservationAndStationRoutesNameExactPathsAndAskForGeoJSON() throws {
    let forecast = try #require(Endpoint.zoneForecast(identifier: "TXZ192", type: .forecast))
    let observations = Endpoint.observations(
      inForecastZone: try ZoneObservationQuery(limit: 2, zoneIdentifier: "TXZ192"))
    let stations = try #require(Endpoint.observationStations(inForecastZone: "TXZ192"))
    #expect(forecast.path == "/zones/forecast/TXZ192/forecast")
    #expect(observations.path == "/zones/forecast/TXZ192/observations?limit=2")
    #expect(stations.path == "/zones/forecast/TXZ192/stations")
    #expect(forecast.accept == .geoJSON)
    #expect(observations.accept == .geoJSON)
    #expect(stations.accept == .geoJSON)
    #expect(forecast.featureFlags.isEmpty)
    #expect(observations.featureFlags.isEmpty)
    #expect(stations.featureFlags.isEmpty)
    #expect(!forecast.path.contains("units"))
    #expect(
      Endpoint.zoneForecast(identifier: "TXZ192", type: AppZoneType.forecast)?.path
        == "/zones/forecast/TXZ192/forecast")
    #expect(
      Endpoint.zoneForecast(identifier: "A/B?x=#%", type: ZoneType(rawValue: "fu/ture"))?.path
        == "/zones/fu%2Fture/A%2FB%3Fx%3D%23%25/forecast")
    #expect(
      Endpoint.observationStations(inForecastZone: "Zoné")?.path
        == "/zones/forecast/Zon%C3%A9/stations")
    #expect(
      Endpoint.observationStations(inForecastZone: "txz192")?.path
        == "/zones/forecast/txz192/stations")
  }

  @Test(
    "Empty and dot forecast and station path arguments are rejected", arguments: ["", ".", ".."])
  func emptyAndDotForecastAndStationPathArgumentsAreRejected(argument: String) {
    #expect(Endpoint.zoneForecast(identifier: argument, type: .forecast) == nil)
    #expect(Endpoint.zoneForecast(identifier: "TXZ192", type: ZoneType(rawValue: argument)) == nil)
    #expect(Endpoint.observationStations(inForecastZone: argument) == nil)
  }

  @Test("Zone path arguments occupy exactly one segment each and keep their case")
  func zonePathArgumentsOccupyExactlyOneSegmentEachAndKeepTheirCase() throws {
    #expect(
      Endpoint.zone(identifier: "A/B?x=#%", type: ZoneType(rawValue: "fu/ture"))?.path
        == "/zones/fu%2Fture/A%2FB%3Fx%3D%23%25")
    #expect(
      Endpoint.zone(identifier: "Zoné", type: .forecast)?.path == "/zones/forecast/Zon%C3%A9")
    #expect(Endpoint.zone(identifier: "txz192", type: .forecast)?.path == "/zones/forecast/txz192")
    #expect(
      Endpoint.zones(matching: try ZoneQuery(), ofType: ZoneType(rawValue: "Fire Weather"))?.path
        == "/zones/Fire%20Weather")
    #expect(
      Endpoint.zone(identifier: "TXZ192", type: AppZoneType.forecast)?.path
        == "/zones/forecast/TXZ192")
  }

  @Test("Empty and dot zone path arguments are rejected", arguments: ["", ".", ".."])
  func emptyAndDotZonePathArgumentsAreRejected(argument: String) throws {
    let query = try ZoneQuery()
    #expect(Endpoint.zone(identifier: argument, type: .forecast) == nil)
    #expect(Endpoint.zone(identifier: "TXZ192", type: ZoneType(rawValue: argument)) == nil)
    #expect(Endpoint.zones(matching: query, ofType: ZoneType(rawValue: argument)) == nil)
  }

  @Test("A zone link becomes its path only on the API origin")
  func aZoneLinkBecomesItsPathOnlyOnTheAPIOrigin() throws {
    let alert = try JSONDecoder().decode(Feature<WeatherAlert>.self, from: Fixture.alert.data())
    let link = try #require(alert.properties.affectedZones.first)
    let followed = try #require(Endpoint<Feature<WeatherZone>>(link: link))
    #expect(followed.path == link.path)
    #expect(followed.accept == .geoJSON)
    let outside = try #require(URL(string: "https://example.com/zones/forecast/TXZ192"))
    #expect(Endpoint<Feature<WeatherZone>>(link: outside) == nil)
  }

  @Test("Alert routes ask for GeoJSON or JSON-LD and never XML")
  func alertRoutesAskForGeoJSONOrJSONLDAndNeverXML() throws {
    #expect(
      Endpoint.activeAlerts(for: try WeatherCoordinate(latitude: 30.2672, longitude: -97.7431))
        .accept.rawValue == "application/geo+json")
    #expect(
      try #require(Endpoint.activeAlerts(inArea: AreaCode(rawValue: "TX"))).accept.rawValue
        == "application/geo+json")
    #expect(
      try #require(Endpoint.activeAlerts(inRegion: .gulfOfMexico)).accept.rawValue
        == "application/geo+json")
    #expect(
      try #require(Endpoint.activeAlerts(inZone: "TXZ192")).accept.rawValue
        == "application/geo+json")
    #expect(Endpoint.activeAlerts(matching: .init()).accept.rawValue == "application/geo+json")
    #expect(Endpoint.alerts(matching: try AlertQuery()).accept.rawValue == "application/geo+json")
    #expect(
      try #require(Endpoint.alert(identifier: "urn:oid:2.49.0.1.840.0.1")).accept.rawValue
        == "application/geo+json")
    #expect(Endpoint.activeAlertCount.accept.rawValue == "application/ld+json")
    #expect(Endpoint.alertTypes.accept.rawValue == "application/ld+json")
  }
}

private enum AppZoneType: String {
  case forecast
}
