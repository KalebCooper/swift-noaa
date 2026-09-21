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

  /// `/glossary`, requested as `application/ld+json`, the whole glossary of 3,183 entries, with
  /// repeated terms, HTML markup, character entities, and carriage return line endings in
  /// definitions.
  case glossary = "Glossary"

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

  /// `/offices/EWX`, requested as `application/ld+json`, the Austin/San Antonio office with an
  /// empty fax number, 33 counties, 33 fire zones, 33 forecast zones, and 63 approved stations.
  case office = "Office"

  /// `/offices/LWX/briefing`, requested as `application/ld+json`, the Baltimore/Washington
  /// office's current briefing with every metadata field, a false priority, and a download link.
  case officeBriefing = "OfficeBriefing"

  /// `/offices/EWX/briefing`, requested as `application/ld+json`, the `null` briefing the
  /// Austin/San Antonio office answered with no current briefing.
  case officeBriefingAbsent = "OfficeBriefingAbsent"

  /// `/offices/EWX/headlines/ab45482ca5f57ff412eb1320721d5ac9`, requested as
  /// `application/ld+json`, one headline with a `null` summary, HTML content, and an editorial
  /// link outside the API origin.
  case officeHeadline = "OfficeHeadline"

  /// `/offices/EWX/headlines`, requested as `application/ld+json`, the two headlines the
  /// Austin/San Antonio office published.
  case officeHeadlines = "OfficeHeadlines"

  /// `/offices/OUN/headlines`, requested as `application/ld+json`, the empty headline list the
  /// Norman office answered.
  case officeHeadlinesEmpty = "OfficeHeadlinesEmpty"

  /// `/points/30.2672,-97.7431`, downtown Austin.
  case point = "Point"

  /// `/points/0,0`, the `404` problem details the API answers a point outside its coverage with.
  case problemDetail = "ProblemDetail"

  /// `/products/a6addd61-6620-4718-9d53-effd7d8c2560`, requested as `application/ld+json`, one
  /// area forecast discussion with its full bulletin text.
  case product = "Product"

  /// `/products/types/AFD/locations/EWX/latest`, requested as `application/ld+json`, the latest
  /// area forecast discussion for Austin/San Antonio, the same product ``product`` was recorded
  /// from.
  case productLatest = "ProductLatest"

  /// `/products/locations`, requested as `application/ld+json`, the 1,693 locations the service
  /// issues text products for, 1,562 of them listed with a `null` description.
  case productLocations = "ProductLocations"

  /// `/products/types/AFD/locations`, requested as `application/ld+json`, the 123 offices that
  /// issue an area forecast discussion, every one of them described.
  case productLocationsForType = "ProductLocationsForType"

  /// `/products?type=AFD&location=EWX&limit=2`, requested as `application/ld+json`, two area
  /// forecast discussions listed without product text.
  case products = "Products"

  /// `/products/types/AFD/locations/EWX`, requested as `application/ld+json`, the 33 area forecast
  /// discussions listed for Austin/San Antonio, none of them with product text.
  case productsAtLocation = "ProductsAtLocation"

  /// `/products/types/AFD`, requested as `application/ld+json`, the 4,567 area forecast
  /// discussions the service listed, none of them with product text.
  case productsOfType = "ProductsOfType"

  /// `/products/types`, requested as `application/ld+json`, the 338 kinds of text product the
  /// service issues.
  case productTypes = "ProductTypes"

  /// `/products/locations/EWX/types`, requested as `application/ld+json`, the 20 kinds of product
  /// the Austin/San Antonio office issues.
  case productTypesAtLocation = "ProductTypesAtLocation"

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

  /// `/zones/forecast/TXZ192/forecast`, the Travis forecast zone's six text-only periods with the
  /// zone's polygon.
  case zoneForecast = "ZoneForecast"

  /// `/zones/marine/GMZ330`, the Matagorda Bay zone answered by the marine route with the reported
  /// type `coastal`, a `null` state, and a 93-ring polygon.
  case zoneMarine = "ZoneMarine"

  /// `/zones/forecast/TXZ192/observations?limit=2`, two observations from different stations in the
  /// Travis forecast zone, with a continuation link that names one station's history instead.
  case zoneObservations = "ZoneObservations"

  /// `/zones/forecast/TXZ192/observations?start=2026-09-19T00:00:00Z&end=2026-09-20T00:00:00Z&limit=3`,
  /// three observations from different stations inside a time window, with the same
  /// station-history continuation link.
  case zoneObservationsWindow = "ZoneObservationsWindow"

  /// `/zones?area=TX&limit=2`, the first two Texas zones of every type, with `null` geometry and no
  /// continuation.
  case zones = "Zones"

  /// `/zones/forecast?area=TX&limit=2`, the first two Texas forecast zones, reported as `public`,
  /// with `null` geometry and no continuation.
  case zonesOfType = "ZonesOfType"

  /// `/zones/forecast/TXZ192/stations`, the 24 stations of the Travis forecast zone, with a
  /// continuation link that names every station again at a later offset.
  case zoneStations = "ZoneStations"

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
