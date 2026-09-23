import Foundation
import SwiftNWSModels
import SwiftNWSTestSupport
import Testing

@Suite("Zones", .timeLimit(.minutes(suiteTimeLimitMinutes)))
struct ZoneTests {
  // 2026-04-16T18:00:00+00:00 and 2200-01-01T00:00:00+00:00, as every recorded zone reports them.
  private let recordedEffective = Date(timeIntervalSince1970: 1_776_362_400)
  private let recordedExpiration = Date(timeIntervalSince1970: 7_258_118_400)

  @Test("The recorded public zone decodes its identity, dates, links, and polygon")
  func theRecordedPublicZoneDecodesItsIdentityDatesLinksAndPolygon() throws {
    let feature = try JSONDecoder().decode(Feature<WeatherZone>.self, from: Fixture.zone.data())
    let zone = feature.properties

    #expect(feature.id == URL(string: "https://api.weather.gov/zones/forecast/TXZ192"))
    #expect(zone.id == "TXZ192")
    #expect(zone.name == "Travis")
    #expect(zone.type == .public)
    #expect(zone.effectiveDate == recordedEffective)
    #expect(zone.expirationDate == recordedExpiration)
    #expect(zone.state == .texas)
    #expect(zone.forecastOffice == URL(string: "https://api.weather.gov/offices/EWX"))
    #expect(zone.gridIdentifier == "EWX")
    #expect(zone.awipsLocationIdentifier == "EWX")
    #expect(zone.cwa == ["EWX"])
    #expect(zone.forecastOffices?.map(\.absoluteString) == ["https://api.weather.gov/offices/EWX"])
    #expect(zone.timeZone == ["America/Chicago"])
    #expect(zone.observationStations?.count == 24)
    #expect(
      zone.observationStations?.first == URL(string: "https://api.weather.gov/stations/KATT"))
    #expect(zone.observationStations?.last == URL(string: "https://api.weather.gov/stations/KTPL"))
    #expect(zone.radarStation == "GRK")
    guard case .object(let geometry) = feature.geometry,
      case .array(let rings) = geometry["coordinates"]
    else {
      Issue.record("Expected a polygon geometry object")
      return
    }
    #expect(geometry["type"] == .string("Polygon"))
    #expect(rings.count == 1)
    guard case .array(let points) = rings[0], case .array(let first) = points[0] else {
      Issue.record("Expected a ring of coordinate pairs")
      return
    }
    #expect(points.count == 223)
    #expect(first == [.number(-97.371796), .number(30.417212)])
  }

  @Test("The recorded county zone keeps an empty station list and a null radar station")
  func theRecordedCountyZoneKeepsAnEmptyStationListAndANullRadarStation() throws {
    let feature = try JSONDecoder().decode(
      Feature<WeatherZone>.self, from: Fixture.zoneCounty.data())
    let zone = feature.properties

    #expect(feature.id == URL(string: "https://api.weather.gov/zones/county/TXC453"))
    #expect(zone.id == "TXC453")
    #expect(zone.type == .county)
    #expect(zone.name == "Travis")
    #expect(zone.state == .texas)
    #expect(zone.observationStations == [])
    #expect(zone.radarStation == nil)
    #expect(zone.effectiveDate == recordedEffective)
    #expect(zone.expirationDate == recordedExpiration)
    #expect(feature.geometry != nil)
  }

  @Test("The marine route answers a coastal zone with a null state and a forecast identity link")
  func theMarineRouteAnswersACoastalZoneWithANullStateAndAForecastIdentityLink() throws {
    let feature = try JSONDecoder().decode(
      Feature<WeatherZone>.self, from: Fixture.zoneMarine.data())
    let zone = feature.properties

    // The service identifies the zone under /zones/forecast/ even when requested through /marine/.
    #expect(feature.id == URL(string: "https://api.weather.gov/zones/forecast/GMZ330"))
    #expect(zone.id == "GMZ330")
    #expect(zone.type == .coastal)
    #expect(zone.name == "Matagorda Bay")
    #expect(zone.state == nil)
    #expect(zone.observationStations == [])
    #expect(zone.radarStation == nil)
    #expect(zone.forecastOffice == URL(string: "https://api.weather.gov/offices/HGX"))
    guard case .object(let geometry) = feature.geometry,
      case .array(let rings) = geometry["coordinates"]
    else {
      Issue.record("Expected a polygon geometry object")
      return
    }
    #expect(geometry["type"] == .string("Polygon"))
    #expect(rings.count == 93)
  }

  @Test("The recorded root directory lists zones in service order with null geometry")
  func theRecordedRootDirectoryListsZonesInServiceOrderWithNullGeometry() throws {
    let zones = try JSONDecoder().decode(
      FeatureCollection<WeatherZone>.self, from: Fixture.zones.data())

    #expect(zones.features.map(\.properties.id) == ["TXC001", "TXC003"])
    #expect(zones.features.map(\.properties.name) == ["Anderson", "Andrews"])
    #expect(zones.features.allSatisfy { $0.properties.type == .county })
    #expect(zones.features.allSatisfy { $0.geometry == nil })
    #expect(zones.features.allSatisfy { $0.properties.observationStations == [] })
    #expect(zones.features.allSatisfy { $0.properties.radarStation == nil })
    #expect(
      zones.features.map(\.id) == [
        URL(string: "https://api.weather.gov/zones/county/TXC001"),
        URL(string: "https://api.weather.gov/zones/county/TXC003"),
      ])
    #expect(zones.pagination == nil)
  }

  @Test("The recorded typed directory reports public zones with their stations and radar")
  func theRecordedTypedDirectoryReportsPublicZonesWithTheirStationsAndRadar() throws {
    let zones = try JSONDecoder().decode(
      FeatureCollection<WeatherZone>.self, from: Fixture.zonesOfType.data())

    #expect(zones.features.map(\.properties.id) == ["TXZ001", "TXZ002"])
    #expect(zones.features.allSatisfy { $0.properties.type == .public })
    #expect(zones.features.allSatisfy { $0.geometry == nil })
    #expect(zones.features.map(\.properties.radarStation) == ["AMA", "AMA"])
    #expect(
      zones.features[0].properties.observationStations?.map(\.absoluteString) == [
        "https://api.weather.gov/stations/KDHT", "https://api.weather.gov/stations/KCAO",
      ])
    #expect(zones.pagination == nil)
  }

  @Test("The recorded zone station list keeps every station and its ignored continuation")
  func theRecordedZoneStationListKeepsEveryStationAndItsIgnoredContinuation() throws {
    let stations = try JSONDecoder().decode(
      FeatureCollection<ObservationStation>.self, from: Fixture.zoneStations.data())
    #expect(stations.features.count == 24)
    #expect(stations.features.first?.properties.stationIdentifier == "K3T5")
    #expect(stations.features.last?.properties.stationIdentifier == "KTPL")
    #expect(stations.features.allSatisfy { $0.properties.forecast != nil })
    #expect(stations.pagination?.next?.hasPrefix("https://api.weather.gov/stations?id") == true)
    #expect(stations.pagination?.next?.hasSuffix("&cursor=eyJzIjo1MDB9") == true)
  }

  @Test(
    "The recorded zone observation lists keep multi-station results and their station-history link",
    arguments: [false, true])
  func theRecordedZoneObservationListsKeepMultiStationResultsAndTheirStationHistoryLink(
    window: Bool
  ) throws {
    let observations = try JSONDecoder().decode(
      FeatureCollection<WeatherObservation>.self,
      from: (window ? Fixture.zoneObservationsWindow : Fixture.zoneObservations).data())
    let stations = observations.features.compactMap(\.properties.station?.absoluteString)
    #expect(stations.count == observations.features.count)
    #expect(
      stations
        == (window
          ? [
            "https://api.weather.gov/stations/KHYI", "https://api.weather.gov/stations/KILE",
            "https://api.weather.gov/stations/K3T5",
          ]
          : ["https://api.weather.gov/stations/KAUS", "https://api.weather.gov/stations/KBAZ"]))
    #expect(Set(stations).count == stations.count)
    #expect(
      observations.pagination?.next?.hasPrefix(
        "https://api.weather.gov/stations/KATT/observations?cursor=") == true)
  }

  @Test("Unknown zone types, region codes, and an empty state survive a Codable round trip")
  func unknownZoneTypesRegionCodesAndAnEmptyStateSurviveACodableRoundTrip() throws {
    let zone = WeatherZone(
      id: "XXZ999", name: "Future", state: AreaCode(rawValue: ""),
      type: ZoneType(rawValue: "future"))
    let feature = Feature(geometry: .null, id: nil, properties: zone)

    let data = try JSONEncoder().encode(feature)
    let decoded = try JSONDecoder().decode(Feature<WeatherZone>.self, from: data)

    #expect(decoded.properties.type.rawValue == "future")
    #expect(decoded.properties.state == AreaCode(rawValue: ""))
    #expect(decoded.properties.state != nil)
    #expect(decoded.properties.effectiveDate == nil)
    #expect(decoded.properties.observationStations == nil)
    // A null geometry decodes as nil, so the round trip drops the null rather than the feature.
    #expect(decoded.geometry == nil)
    #expect(decoded.properties == zone)

    let region = try JSONDecoder().decode(ZoneRegionCode.self, from: Data("\"XR\"".utf8))
    #expect(region.rawValue == "XR")
    #expect(try JSONEncoder().encode(region) == Data("\"XR\"".utf8))
  }

  @Test("A zone with only its identity decodes, and missing identity fails")
  func aZoneWithOnlyItsIdentityDecodesAndMissingIdentityFails() throws {
    let minimal = try JSONDecoder().decode(
      WeatherZone.self, from: Data(#"{"id":"TXZ192","name":"Travis","type":"public"}"#.utf8))
    #expect(minimal == WeatherZone(id: "TXZ192", name: "Travis", type: .public))

    #expect(throws: DecodingError.self) {
      try JSONDecoder().decode(
        WeatherZone.self, from: Data(#"{"name":"Travis","type":"public"}"#.utf8))
    }
    #expect(throws: DecodingError.self) {
      try JSONDecoder().decode(
        WeatherZone.self, from: Data(#"{"id":"TXZ192","name":"Travis"}"#.utf8))
    }
  }

  @Test("A present but malformed date fails decoding")
  func aPresentButMalformedDateFailsDecoding() {
    #expect(throws: DecodingError.self) {
      try JSONDecoder().decode(
        WeatherZone.self,
        from: Data(
          #"{"id":"TXZ192","name":"Travis","type":"public","effectiveDate":"yesterday"}"#.utf8))
    }
  }

  @Test("Zone dates encode as ISO 8601 text independent of the coder's date strategy")
  func zoneDatesEncodeAsISO8601TextIndependentOfTheCodersDateStrategy() throws {
    let zone = WeatherZone(
      effectiveDate: recordedEffective, expirationDate: recordedExpiration, id: "TXZ192",
      name: "Travis", type: .public)
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .secondsSince1970
    let json = try #require(String(data: encoder.encode(zone), encoding: .utf8))
    #expect(json.contains(#""effectiveDate":"2026-04-16T18:00:00.000Z""#))
    #expect(json.contains(#""expirationDate":"2200-01-01T00:00:00.000Z""#))

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .secondsSince1970
    let decoded = try decoder.decode(
      Feature<WeatherZone>.self, from: Fixture.zone.data()
    ).properties
    #expect(decoded.effectiveDate == recordedEffective)
  }

  @Test("Geometry survives encoding and decoding, and missing geometry is nil")
  func geometrySurvivesEncodingAndDecodingAndMissingGeometryIsNil() throws {
    let recorded = try JSONDecoder().decode(Feature<WeatherZone>.self, from: Fixture.zone.data())
    let data = try JSONEncoder().encode(recorded)
    let decoded = try JSONDecoder().decode(Feature<WeatherZone>.self, from: data)
    #expect(decoded == recorded)
    #expect(decoded.geometry == recorded.geometry)

    let missing = try JSONDecoder().decode(
      Feature<WeatherZone>.self,
      from: Data(#"{"properties":{"id":"TXZ192","name":"Travis","type":"public"}}"#.utf8))
    #expect(missing.geometry == nil)
    #expect(
      missing == Feature(properties: WeatherZone(id: "TXZ192", name: "Travis", type: .public)))

    let encoded = try #require(String(data: JSONEncoder().encode(missing), encoding: .utf8))
    #expect(!encoded.contains("geometry"))
  }

  @Test("Every previously recorded feature still decodes and compares after the geometry change")
  func everyPreviouslyRecordedFeatureStillDecodesAndComparesAfterTheGeometryChange() throws {
    let decoder = JSONDecoder()
    let point = try decoder.decode(Feature<WeatherPoint>.self, from: Fixture.point.data())
    #expect(point.properties.gridId == "EWX")
    #expect(point.geometry != nil)

    let observation = try decoder.decode(
      Feature<WeatherObservation>.self, from: Fixture.observation.data())
    #expect(observation.properties.stationId == "KATT")
    #expect(
      observation
        == Feature(
          geometry: observation.geometry, id: observation.id, properties: observation.properties))

    let station = try decoder.decode(
      Feature<ObservationStation>.self, from: Fixture.observationStation.data())
    #expect(station.properties.stationIdentifier == "KATT")

    let alert = try decoder.decode(Feature<WeatherAlert>.self, from: Fixture.alert.data())
    #expect(!alert.properties.id.isEmpty)

    let forecast = try decoder.decode(Feature<WeatherForecast>.self, from: Fixture.forecast.data())
    #expect(!forecast.properties.periods.isEmpty)

    let grid = try decoder.decode(Feature<ForecastGrid>.self, from: Fixture.forecastGrid.data())
    #expect(grid.geometry != nil)
    #expect(grid.properties[.temperature] != nil)

    let stations = try decoder.decode(
      FeatureCollection<ObservationStation>.self, from: Fixture.observationStations.data())
    #expect(stations.features.count == 64)

    let alerts = try decoder.decode(
      FeatureCollection<WeatherAlert>.self, from: Fixture.activeAlerts.data())
    #expect(!alerts.features.isEmpty)
  }

  @Test("Consumer String-backed enums convert to zone types and region codes")
  func consumerStringBackedEnumsConvertToZoneTypesAndRegionCodes() {
    #expect(ZoneType(AppZoneType.forecast) == .forecast)
    #expect(ZoneType(AppZoneType.future).rawValue == "future")
    #expect(ZoneRegionCode(AppRegion.southern) == .southernRegion)
    #expect(ZoneRegionCode(MarineRegionCode.atlantic) == .atlantic)
    #expect(ZoneRegionCode(MarineRegionCode.alaska) == .alaska)
    #expect(ZoneRegionCode.alaska != .alaskaRegion)
    #expect(ZoneRegionCode.alaskaRegion.rawValue == "AR")
    #expect(ZoneType.public.rawValue == "public")
  }

  @Test("Every named zone type and region code matches the live schema")
  func everyNamedZoneTypeAndRegionCodeMatchesTheLiveSchema() {
    let types: [ZoneType] = [
      .coastal, .county, .fire, .forecast, .land, .marine, .offshore, .public,
    ]
    #expect(
      types.map(\.rawValue) == [
        "coastal", "county", "fire", "forecast", "land", "marine", "offshore", "public",
      ])
    let regions: [ZoneRegionCode] = [
      .alaskaRegion, .centralRegion, .easternRegion, .pacificRegion, .southernRegion,
      .westernRegion, .alaska, .atlantic, .greatLakes, .gulfOfMexico, .pacific, .pacificIslands,
    ]
    #expect(
      regions.map(\.rawValue) == [
        "AR", "CR", "ER", "PR", "SR", "WR", "AL", "AT", "GL", "GM", "PA", "PI",
      ])
  }
}

private enum AppZoneType: String {
  case forecast
  case future
}

private enum AppRegion: String {
  case southern = "SR"
}
