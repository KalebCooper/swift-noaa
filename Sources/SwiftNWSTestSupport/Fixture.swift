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

  /// `/gridpoints/EWX/156,91`, the raw forecast grid for downtown Austin that ``point`` links to,
  /// with every layer the schema lists, empty layers, layers without a unit, and null values.
  case forecastGrid = "ForecastGrid"

  /// `/gridpoints/ABQ/80,183`, a raw forecast grid in New Mexico with a flood watch in its hazards
  /// layer and heavy rain attributes in its weather layer.
  case forecastGridHazards = "ForecastGridHazards"

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

  /// `/alerts/active/region/XX`, the `404` problem details the API answers an unknown marine region
  /// with, listing the valid region codes in its parameter errors.
  case unknownRegionProblem = "UnknownRegionProblem"

  /// `/zones/forecast/TXZ192`, the Travis public forecast zone with its polygon and 24 stations.
  case zone = "Zone"

  /// `/alerts/active/zone/TXZ192`, active alerts in the Travis forecast zone.
  case zoneAlerts = "ZoneAlerts"

  /// `/zones/county/TXC453`, the Travis county zone with its polygon, no observation stations, and
  /// a `null` radar station.
  case zoneCounty = "ZoneCounty"

  /// `/zones/marine/GMZ330`, the Matagorda Bay zone answered by the marine route with the reported
  /// type `coastal`, a `null` state, and a 93-ring polygon.
  case zoneMarine = "ZoneMarine"

  /// `/zones?area=TX&limit=2`, the first two Texas zones of every type, with `null` geometry and no
  /// continuation.
  case zones = "Zones"

  /// `/zones/forecast?area=TX&limit=2`, the first two Texas forecast zones, reported as `public`,
  /// with `null` geometry and no continuation.
  case zonesOfType = "ZonesOfType"

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
