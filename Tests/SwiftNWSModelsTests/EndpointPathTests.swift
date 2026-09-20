import Foundation
import SwiftNWSModels
import SwiftNWSTestSupport
import Testing

@Suite("Endpoint path validation", .timeLimit(.minutes(suiteTimeLimitMinutes)))
struct EndpointPathTests {
  private enum Flag: String {
    case custom = "custom_flag"
  }

  @Test(
    "Accepted links retain their exact encoded path and query",
    arguments: [
      "https://api.weather.gov/", "https://API.WEATHER.GOV:443/stations",
      "https://api.weather.gov/a%2fb?x=%e2%98%83&x=%2F&ids%5B%5D=A&api_key=allowed",
      "https://api.weather.gov/stations?cursor=../a%5Cb%20c&empty=&flag",
    ])
  func acceptedLinksRetainTheirExactEncodedPathAndQuery(link: String) throws {
    let url = try #require(URL(string: link, encodingInvalidCharacters: false))
    let endpoint = try #require(Endpoint<Int>(link: url))
    let pathStart = try #require(link.dropFirst("https://".count).firstIndex(of: "/"))
    let expected = String(link[pathStart...])
    #expect(endpoint.path == expected)
    #expect(Endpoint<Int>(featureFlags: [Flag.custom], link: url)?.path == expected)
  }

  @Test(
    "Accepted relative paths retain every byte",
    arguments: [
      "/", "/stations", "/stations?", "/stations?flag&empty=&id=A&id=B",
      "/a%2fb/%E2%98%83%20station?cursor=%e2%98%83%2f%3D",
      "/stations?id[0]=KATT&id%5B1%5D=KXYZ&api_key=allowed",
      "/stations?cursor=../a%5Cb%20c%23encoded",
      "/a%23b%3Fc?cursor=%25&next=//host/../path",
      "/a//b/", "/station.name",
    ])
  func acceptedRelativePathsRetainEveryByte(path: String) throws {
    var endpoint = try #require(Endpoint<Int>(path: path))
    endpoint.accept = .jsonLD
    endpoint.featureFlags = [.init(rawValue: "future")]
    #expect(endpoint.path == path)
    #expect(endpoint.accept == .jsonLD)
    #expect(endpoint.featureFlags == [.init(rawValue: "future")])
    #expect(Endpoint<Int>(featureFlags: [Flag.custom], path: path)?.path == path)
  }

  @Test("Built-in query factories encode arbitrary values without changing the path")
  func builtInQueryFactoriesEncodeArbitraryValuesWithoutChangingThePath() throws {
    let cursor = "../\\ #%\n雪"
    let station = Endpoint.observationStations(
      query: try ObservationStationQuery(cursor: cursor, identifiers: [cursor]))
    let observations = Endpoint.observations(
      query: try ObservationQuery(cursor: cursor, stationIdentifier: "A B"))
    let alerts = Endpoint.alerts(matching: try AlertQuery(cursor: cursor))
    let active = Endpoint.activeAlerts(matching: .init(event: [cursor]))
    for path in [station.path, observations.path, alerts.path, active.path] {
      #expect(Endpoint<Int>(path: path)?.path == path)
    }
    #expect(observations.path.hasPrefix("/stations/A%20B/observations?"))
  }

  @Test("Forecast reconstruction preserves opaque query fields and safely encodes units")
  func forecastReconstructionPreservesOpaqueQueryFieldsAndSafelyEncodesUnits() throws {
    var point = try JSONDecoder().decode(Feature<Point>.self, from: Fixture.point.data()).properties
    let path = "/gridpoints/EWX/156,91/forecast?cursor=a%2fb%3D&id%5B%5D=A&id%5B%5D=B&%75nits=us"
    point.forecast = try #require(
      URL(string: "https://api.weather.gov" + path, encodingInvalidCharacters: false))
    point.forecastHourly = point.forecast
    let options = ForecastOptions(
      featureFlags: [.windSpeedQuantity, .temperatureQuantity],
      units: .init(rawValue: "future #\\%"))
    for endpoint in [
      Endpoint.forecast(for: point, options: options),
      Endpoint.hourlyForecast(for: point, options: options),
    ] {
      let endpoint = try #require(endpoint)
      #expect(
        endpoint.path
          == "/gridpoints/EWX/156,91/forecast?cursor=a%2fb%3D&id%5B%5D=A&id%5B%5D=B&units=future%20%23%5C%25"
      )
      #expect(endpoint.featureFlags == [.temperatureQuantity, .windSpeedQuantity])
    }
  }

  @Test(
    "Invalid identifiers fail safely in every path factory",
    arguments: ["", ".", "..", "../A", "A/../B", "A\\B", "A\nB", "A\u{0}B"])
  func invalidIdentifiersFailSafelyInEveryPathFactory(identifier: String) {
    #expect(Endpoint.alert(identifier: identifier) == nil)
    #expect(Endpoint.latestObservation(stationIdentifier: identifier) == nil)
    #expect(Endpoint.observationStation(identifier: identifier) == nil)
    #expect(
      Endpoint.observation(stationIdentifier: identifier, timestamp: Date(timeIntervalSince1970: 0))
        == nil)
    #expect(Endpoint.activeAlerts(inArea: AreaCode(rawValue: identifier)) == nil)
    #expect(Endpoint.activeAlerts(inRegion: MarineRegionCode(rawValue: identifier)) == nil)
    #expect(Endpoint.activeAlerts(inZone: identifier) == nil)
    #expect(WeatherRequest.activeAlerts(inArea: AreaCode(rawValue: identifier)) == nil)
    #expect(WeatherRequest.activeAlerts(inRegion: MarineRegionCode(rawValue: identifier)) == nil)
    #expect(WeatherRequest.activeAlerts(inZone: identifier) == nil)
    #expect(throws: ObservationQuery.ValidationError.invalidStationIdentifier) {
      try ObservationQuery(stationIdentifier: identifier)
    }
  }

  @Test(
    "Invalid links cannot acquire an endpoint",
    arguments: [
      "http://api.weather.gov/stations", "https://example.com/stations",
      "https://api.weather.gov.example.com/stations", "https://api.weather.gov:444/stations",
      "https://user@api.weather.gov/stations", "https://user:pass@api.weather.gov/stations",
      "https://api.weather.gov/stations#", "https://api.weather.gov",
      "https://api.weather.gov//host", "https://api.weather.gov/%2fhost",
      "https://api.weather.gov/a/../b", "https://api.weather.gov/a/%2e%2E/b",
      "https://api.weather.gov/a%2f..%2fb", "https://api.weather.gov/a%5cb",
      "https://api.weather.gov/a%0Ab", "https://api.weather.gov/a b",
      "https://api.weather.gov/a%", "https://api.weather.gov/a%0G",
    ])
  func invalidLinksCannotAcquireAnEndpoint(link: String) {
    let endpoint = URL(string: link, encodingInvalidCharacters: false).flatMap {
      Endpoint<Int>(link: $0)
    }
    #expect(endpoint == nil)
  }

  @Test(
    "Invalid relative paths are rejected without normalization",
    arguments: [
      "", "stations", "?cursor=1", "https://api.weather.gov/stations", "//host", "///host",
      "/%2fhost", "/%2F%2fhost", "/.", "/..", "/a/./b", "/a/../b", "/a/..",
      "/%2e", "/.%2E", "/%2e./", "/a%2f..%2fb", "/a/%2E/b",
      "/a\\b", "/a%5Cb", "/a%5cb", "/a b", "/a\tb", "/a\nb", "/a\rb",
      "/a\u{0}b", "/a\u{7f}b", "/a\u{a0}b", "/a#b", "/a?x=#b",
      "/a%", "/a%2", "/a%GG", "/a?x=%", "/a?x=%2Z", "/a?x=raw space",
      "/a%00b", "/a%0db", "/a%7Fb", "/a%C2%85b", "/a<b", "/雪",
    ])
  func invalidRelativePathsAreRejectedWithoutNormalization(path: String) {
    #expect(Endpoint<Int>(path: path) == nil)
    #expect(Endpoint<Int>(featureFlags: [Flag.custom], path: path) == nil)
  }
}
