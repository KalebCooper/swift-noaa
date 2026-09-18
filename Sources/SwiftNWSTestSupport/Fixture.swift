import Foundation

/// A response body recorded from the live National Weather Service API.
///
/// Tests never reach the API. Each case is one body captured once and kept in `Fixtures/`, so a test
/// decodes exactly what the service sent.
///
/// ```swift
/// let point = try JSONDecoder().decode(Feature<Point>.self, from: Fixture.point.data())
/// ```
package enum Fixture: String, CaseIterable, Sendable {
  /// `/alerts/active/count`, requested as `application/ld+json`, with every breakdown populated.
  case activeAlertCount = "ActiveAlertCount"

  /// `/alerts/active?point=30.2672,-97.7431`, covering typed CAP codes at downtown Austin.
  case activeAlerts = "ActiveAlerts"

  /// One `/alerts/{id}` response covering typed CAP codes and optional fields.
  case alert = "Alert"

  /// `/alerts?area=TX&end=2026-09-17T00:00:00Z&limit=2&start=2026-09-16T00:00:00Z&status=actual`,
  /// one page of Texas alert history with its continuation link.
  case alertHistory = "AlertHistory"

  /// `/alerts/types`, requested as `application/ld+json`, the recognized event names.
  case alertTypes = "AlertTypes"

  /// `/alerts/active/area/TX`, covering the typed Texas area path and CAP codes.
  case areaAlerts = "AreaAlerts"

  /// `/gridpoints/EWX/156,91/forecast?units=us`, covering US units and legacy code values.
  case forecast = "Forecast"

  /// `/gridpoints/EWX/156,91/forecast?units=si`, covering SI units and both quantitative flags.
  case forecastQuantities = "ForecastQuantities"

  /// `/gridpoints/EWX/156,91/forecast/hourly?units=us`, covering US units and compass codes.
  case hourlyForecast = "HourlyForecast"

  /// `/gridpoints/EWX/156,91/forecast/hourly?units=si`, covering SI units and quantitative flags.
  case hourlyForecastQuantities = "HourlyForecastQuantities"

  /// `/stations/KATT/observations/latest`, the latest observation from Austin Camp Mabry.
  case observation = "Observation"

  /// `/stations/KATT/observations/2026-09-18T01:51:00Z`, the Austin Camp Mabry observation made at
  /// that exact instant.
  case observationAtTimestamp = "ObservationAtTimestamp"

  /// `/stations/KATT/observations?end=2026-09-17T00:00:00Z&limit=2&start=2026-09-16T00:00:00Z`,
  /// one page of Austin Camp Mabry observation history with its continuation link.
  case observationHistory = "ObservationHistory"

  /// `/stations/KATT/observations/2026-09-18T01:50:00Z`, the `404` problem details the API answers
  /// an instant with no observation with.
  case observationNotFound = "ObservationNotFound"

  /// `/stations/KATT`, the metadata for Austin Camp Mabry.
  case observationStation = "ObservationStation"

  /// `/gridpoints/EWX/156,91/stations`, the 64 stations near downtown Austin, nearest first.
  case observationStations = "ObservationStations"

  /// `/stations/KPWM/observations/2026-09-18T02:50:00Z`, a Portland International Jetport
  /// observation reporting heavy rain and mist under three cloud layers, with an empty raw message
  /// and no one-hour or six-hour precipitation fields.
  case observationWithWeather = "ObservationWithWeather"

  /// `/points/30.2672,-97.7431`, downtown Austin.
  case point = "Point"

  /// `/points/0,0`, the `404` problem details the API answers a point outside its coverage with.
  case problemDetail = "ProblemDetail"

  /// `/alerts/active/region/AT`, active alerts in the Atlantic marine region.
  case regionAlerts = "RegionAlerts"

  /// `/alerts/active/zone/TXZ192`, active alerts in the Travis forecast zone.
  case zoneAlerts = "ZoneAlerts"

  /// The recorded body.
  ///
  /// - Throws: ``FixtureFailure/missing(name:)`` when the file is not in the bundle, and whatever
  ///   reading it throws.
  package func data() throws -> Data {
    guard
      let url = Bundle.module.url(
        forResource: rawValue, withExtension: "json", subdirectory: "Fixtures")
    else {
      throw FixtureFailure.missing(name: rawValue)
    }
    return try Data(contentsOf: url)
  }
}

/// Why a recorded body could not be read.
package enum FixtureFailure: Error, Hashable, Sendable {
  /// No file with this name is in the bundle's `Fixtures/` directory.
  case missing(name: String)
}
