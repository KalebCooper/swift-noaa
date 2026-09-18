#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// A weather station that reports observations, as `/stations/{stationId}` describes it or a station
/// collection lists it.
///
/// Every field other than the name and identifier is optional because the service omits some of them
/// for some stations. The distance and bearing appear only in a list relative to a location, such as
/// a point's station list. Provider names are kept as the service sends them, including empty strings.
///
/// ```swift
/// let stations = try JSONDecoder().decode(FeatureCollection<ObservationStation>.self, from: body)
/// print(stations.features.first?.properties.stationIdentifier ?? "none")  // "KATT"
/// ```
public struct ObservationStation: Codable, Hashable, Sendable {
  /// The station's bearing from the location a list was requested for.
  public var bearing: QuantitativeValue?

  /// A link to the county zone containing the station.
  public var county: URL?

  /// The station's distance from the location a list was requested for.
  public var distance: QuantitativeValue?

  /// The station's elevation.
  public var elevation: QuantitativeValue?

  /// A link to the fire weather forecast zone containing the station.
  public var fireWeatherZone: URL?

  /// A link to the public forecast zone containing the station.
  public var forecast: URL?

  /// The station's name, such as `Austin City Austin Camp Mabry`.
  public var name: String

  /// The data provider for the station, such as `ASOS`.
  public var provider: String?

  /// The station's identifier, such as `KATT`.
  public var stationIdentifier: String

  /// The data sub-provider for the station, such as `FAA`, which the service may send empty.
  public var subProvider: String?

  /// The IANA time zone identifier for the station, such as `America/Chicago`.
  public var timeZone: String?

  /// Creates an observation station.
  ///
  /// - Parameters:
  ///   - bearing: The station's bearing from a requested location.
  ///   - county: A link to the county zone containing the station.
  ///   - distance: The station's distance from a requested location.
  ///   - elevation: The station's elevation.
  ///   - fireWeatherZone: A link to the fire weather forecast zone containing the station.
  ///   - forecast: A link to the public forecast zone containing the station.
  ///   - name: The station's name.
  ///   - provider: The data provider for the station.
  ///   - stationIdentifier: The station's identifier.
  ///   - subProvider: The data sub-provider for the station.
  ///   - timeZone: The IANA time zone identifier for the station.
  public init(
    bearing: QuantitativeValue? = nil,
    county: URL? = nil,
    distance: QuantitativeValue? = nil,
    elevation: QuantitativeValue? = nil,
    fireWeatherZone: URL? = nil,
    forecast: URL? = nil,
    name: String,
    provider: String? = nil,
    stationIdentifier: String,
    subProvider: String? = nil,
    timeZone: String? = nil
  ) {
    self.bearing = bearing
    self.county = county
    self.distance = distance
    self.elevation = elevation
    self.fireWeatherZone = fireWeatherZone
    self.forecast = forecast
    self.name = name
    self.provider = provider
    self.stationIdentifier = stationIdentifier
    self.subProvider = subProvider
    self.timeZone = timeZone
  }
}
