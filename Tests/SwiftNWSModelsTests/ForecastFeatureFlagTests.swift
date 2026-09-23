import Foundation
import SwiftNWSModels
import SwiftNWSTestSupport
import Testing

@Suite("Forecast feature flags", .timeLimit(.minutes(suiteTimeLimitMinutes)))
struct ForecastFeatureFlagTests {
  @Test("Each modeled flag sends the specification's raw value")
  func eachModeledFlagSendsTheSpecificationsRawValue() {
    let modeled: [ForecastFeatureFlag] = [.temperatureQuantity, .windSpeedQuantity]

    #expect(modeled.map(\.rawValue) == ["forecast_temperature_qv", "forecast_wind_speed_qv"])
  }

  @Test("An unknown flag reaches both forecast endpoints unchanged")
  func anUnknownFlagReachesBothForecastEndpointsUnchanged() throws {
    let point = try recordedPoint()
    let options = ForecastOptions(featureFlags: [ForecastFeatureFlag(rawValue: "future_flag")])

    let forecast = try #require(Endpoint.forecast(for: point, options: options))
    let hourly = try #require(Endpoint.hourlyForecast(for: point, options: options))

    #expect(forecast.featureFlags.map(\.rawValue) == ["future_flag"])
    #expect(hourly.featureFlags.map(\.rawValue) == ["future_flag"])
  }

  @Test("Only the forecast and hourly forecast endpoints carry flags")
  func onlyTheForecastAndHourlyForecastEndpointsCarryFlags() throws {
    let point = try recordedPoint()
    let location = try WeatherCoordinate(latitude: 30.2672, longitude: -97.7431)
    let instant = Date(timeIntervalSince1970: 1_789_862_400)
    let options = ForecastOptions(featureFlags: [.temperatureQuantity, .windSpeedQuantity])

    let unflagged: [String: [ForecastFeatureFlag]?] = [
      "activeAlertCount": Endpoint.activeAlertCount.featureFlags,
      "activeAlerts(for:)": Endpoint.activeAlerts(for: location).featureFlags,
      "activeAlerts(inArea:)": Endpoint.activeAlerts(inArea: AreaCode(rawValue: "TX"))?
        .featureFlags,
      "activeAlerts(inRegion:)": Endpoint.activeAlerts(inRegion: .gulfOfMexico)?.featureFlags,
      "activeAlerts(inZone:)": Endpoint.activeAlerts(inZone: "TXZ192")?.featureFlags,
      "activeAlerts(matching:)": Endpoint.activeAlerts(matching: .init()).featureFlags,
      "alert(identifier:)": Endpoint.alert(identifier: "urn:oid:2.49.0.1.840.0.1")?.featureFlags,
      "alerts(matching:)": Endpoint.alerts(matching: try AlertQuery()).featureFlags,
      "alertTypes": Endpoint.alertTypes.featureFlags,
      "forecastGrid(for:)": Endpoint.forecastGrid(for: point)?.featureFlags,
      "glossary": Endpoint.glossary.featureFlags,
      "latestObservation(stationIdentifier:)": Endpoint.latestObservation(
        stationIdentifier: "KATT")?.featureFlags,
      "latestProduct(at:ofType:)": Endpoint.latestProduct(
        at: "EWX", ofType: .areaForecastDiscussion)?.featureFlags,
      "observation(stationIdentifier:timestamp:)": Endpoint.observation(
        stationIdentifier: "KATT", timestamp: instant)?.featureFlags,
      "observationStation(identifier:)": Endpoint.observationStation(identifier: "KATT")?
        .featureFlags,
      "observationStations(inForecastZone:)": Endpoint.observationStations(
        inForecastZone: "TXZ192")?.featureFlags,
      "observationStations(matching:)": Endpoint.observationStations(
        matching: try ObservationStationQuery()
      ).featureFlags,
      "observationStations(near:)": Endpoint.observationStations(near: point)?.featureFlags,
      "observations(inForecastZone:)": Endpoint.observations(
        inForecastZone: try ZoneObservationQuery(zoneIdentifier: "TXZ192")
      ).featureFlags,
      "observations(matching:)": Endpoint.observations(
        matching: try ObservationQuery(stationIdentifier: "KATT")
      ).featureFlags,
      "office(identifier:)": Endpoint.office(identifier: "EWX")?.featureFlags,
      "officeBriefing(officeIdentifier:)": Endpoint.officeBriefing(officeIdentifier: "LWX")?
        .featureFlags,
      "officeHeadline(identifier:officeIdentifier:)": Endpoint.officeHeadline(
        identifier: "headline", officeIdentifier: "EWX")?.featureFlags,
      "officeHeadlines(officeIdentifier:)": Endpoint.officeHeadlines(officeIdentifier: "EWX")?
        .featureFlags,
      "point(for:)": Endpoint.point(for: location).featureFlags,
      "product(identifier:)": Endpoint.product(identifier: "product")?.featureFlags,
      "productLocations": Endpoint.productLocations.featureFlags,
      "productLocations(for:)": Endpoint.productLocations(for: .areaForecastDiscussion)?
        .featureFlags,
      "products(at:ofType:)": Endpoint.products(at: "EWX", ofType: .areaForecastDiscussion)?
        .featureFlags,
      "products(matching:)": Endpoint.products(matching: try ProductQuery()).featureFlags,
      "products(ofType:)": Endpoint.products(ofType: .areaForecastDiscussion)?.featureFlags,
      "productTypes": Endpoint.productTypes.featureFlags,
      "productTypes(at:)": Endpoint.productTypes(at: "EWX")?.featureFlags,
      "zone(identifier:type:effective:)": Endpoint.zone(identifier: "TXZ192", type: .forecast)?
        .featureFlags,
      "zoneForecast(identifier:type:)": Endpoint.zoneForecast(
        identifier: "TXZ192", type: .forecast)?.featureFlags,
      "zones(matching:ofType:)": Endpoint.zones(matching: try ZoneQuery(), ofType: .forecast)?
        .featureFlags,
      "zones(matching:types:)": Endpoint.zones(matching: try ZoneQuery()).featureFlags,
    ]

    #expect(unflagged.count == 37)
    for (factory, flags) in unflagged {
      #expect(flags == [], "\(factory)")
    }
    let expected = ["forecast_temperature_qv", "forecast_wind_speed_qv"]
    #expect(
      Endpoint.forecast(for: point, options: options)?.featureFlags.map(\.rawValue) == expected)
    #expect(
      Endpoint.hourlyForecast(for: point, options: options)?.featureFlags.map(\.rawValue)
        == expected)
  }

  private func recordedPoint() throws -> WeatherPoint {
    try JSONDecoder().decode(Feature<WeatherPoint>.self, from: Fixture.point.data()).properties
  }
}
