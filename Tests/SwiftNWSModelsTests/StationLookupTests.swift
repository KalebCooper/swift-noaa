import Foundation
import SwiftNWSModels
import SwiftNWSTestSupport
import Testing

@Suite("Station and timed-observation lookups", .timeLimit(.minutes(suiteTimeLimitMinutes)))
struct StationLookupTests {
  // 2026-09-18T01:51:00Z, the instant recorded in Fixture.observationAtTimestamp.
  private let recordedTimestamp = Date(timeIntervalSince1970: 1_789_696_260)

  @Test("A recorded observation at a timestamp decodes that exact instant")
  func aRecordedObservationAtATimestampDecodesThatExactInstant() throws {
    let feature = try JSONDecoder().decode(
      Feature<WeatherObservation>.self, from: Fixture.observationAtTimestamp.data())
    let observation = feature.properties

    #expect(
      feature.id?.absoluteString
        == "https://api.weather.gov/stations/KATT/observations/2026-09-18T01:51:00+00:00")
    #expect(observation.stationId == "KATT")
    #expect(observation.timestamp == recordedTimestamp)
    #expect(observation.textDescription == "")
    #expect(
      observation.windGust
        == QuantitativeValue(qualityControl: .screened, unitCode: "wmoUnit:km_h-1", value: 35.28))
    #expect(
      observation.windChill
        == QuantitativeValue(qualityControl: .verified, unitCode: "wmoUnit:degC", value: nil))
  }

  @Test("A recorded station decodes its metadata and zone links")
  func aRecordedStationDecodesItsMetadataAndZoneLinks() throws {
    let feature = try JSONDecoder().decode(
      Feature<ObservationStation>.self, from: Fixture.observationStation.data())

    #expect(feature.id?.absoluteString == "https://api.weather.gov/stations/KATT")
    #expect(
      feature.properties
        == ObservationStation(
          county: URL(string: "https://api.weather.gov/zones/county/TXC453"),
          elevation: QuantitativeValue(unitCode: "wmoUnit:m", value: 199.9488),
          fireWeatherZone: URL(string: "https://api.weather.gov/zones/fire/TXZ192"),
          forecast: URL(string: "https://api.weather.gov/zones/forecast/TXZ192"),
          name: "Austin City Austin Camp Mabry",
          provider: "ASOS",
          stationIdentifier: "KATT",
          subProvider: "",
          timeZone: "America/Chicago"
        ))
  }

  @Test("A station with only its name and identifier decodes without the optional fields")
  func aStationWithOnlyItsNameAndIdentifierDecodesWithoutTheOptionalFields() throws {
    let body = Data(#"{"name":"Future Station","stationIdentifier":"FUTURE"}"#.utf8)
    #expect(
      try JSONDecoder().decode(ObservationStation.self, from: body)
        == ObservationStation(name: "Future Station", stationIdentifier: "FUTURE"))
  }

  @Test("Lookup requests describe their resolutions without sending")
  func lookupRequestsDescribeTheirResolutionsWithoutSending() {
    let station = WeatherRequest.observationStation(identifier: "FUTURE-STATION")
    guard case .observationStation(let identifier) = station.resolution else {
      Issue.record("Expected a station resolution")
      return
    }
    #expect(identifier == "FUTURE-STATION")

    let observation = WeatherRequest.observation(
      stationIdentifier: "KATT", timestamp: recordedTimestamp)
    guard case .observation(let stationIdentifier, let timestamp) = observation.resolution else {
      Issue.record("Expected a timed-observation resolution")
      return
    }
    #expect(stationIdentifier == "KATT")
    #expect(timestamp == recordedTimestamp)
    #expect(observation == .observation(stationIdentifier: "KATT", timestamp: recordedTimestamp))
  }

  @Test("Lookup endpoints name their paths and ask for GeoJSON")
  func lookupEndpointsNameTheirPathsAndAskForGeoJSON() throws {
    let station = try #require(Endpoint.observationStation(identifier: "KATT"))
    let observation = try #require(
      Endpoint.observation(stationIdentifier: "KATT", timestamp: recordedTimestamp))

    #expect(station.path == "/stations/KATT")
    #expect(station.accept == .geoJSON)
    #expect(station.featureFlags.isEmpty)
    #expect(observation.path == "/stations/KATT/observations/2026-09-18T01:51:00Z")
    #expect(observation.accept == .geoJSON)
    #expect(observation.featureFlags.isEmpty)
  }

  @Test("Lookup station identifiers occupy exactly one path segment")
  func lookupStationIdentifiersOccupyExactlyOnePathSegment() throws {
    #expect(
      try #require(Endpoint.observationStation(identifier: "A/B?x=#%")).path
        == "/stations/A%2FB%3Fx%3D%23%25")
    #expect(
      try #require(
        Endpoint.observation(stationIdentifier: "A/B?x=#%", timestamp: recordedTimestamp)
      ).path
        == "/stations/A%2FB%3Fx%3D%23%25/observations/2026-09-18T01:51:00Z")
  }

  @Test("Observation timestamps are sent in UTC with whole-second precision")
  func observationTimestampsAreSentInUTCWithWholeSecondPrecision() throws {
    let endpoint = try #require(
      Endpoint.observation(
        stationIdentifier: "KATT", timestamp: recordedTimestamp.addingTimeInterval(0.75)))
    #expect(endpoint.path == "/stations/KATT/observations/2026-09-18T01:51:00Z")
  }
}
