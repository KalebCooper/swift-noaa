/// A weather station that reports observations, as the API lists it in a station collection.
///
/// ```swift
/// let stations = try JSONDecoder().decode(FeatureCollection<ObservationStation>.self, from: body)
/// print(stations.features.first?.properties.stationIdentifier ?? "none")  // "KATT"
/// ```
public struct ObservationStation: Codable, Hashable, Sendable {
  /// The station's elevation.
  public var elevation: QuantitativeValue?

  /// The station's name, such as `Austin City Austin Camp Mabry`.
  public var name: String

  /// The station's identifier, such as `KATT`.
  public var stationIdentifier: String

  /// The IANA time zone identifier for the station, such as `America/Chicago`.
  public var timeZone: String?

  /// Creates an observation station.
  ///
  /// - Parameters:
  ///   - elevation: The station's elevation.
  ///   - name: The station's name.
  ///   - stationIdentifier: The station's identifier.
  ///   - timeZone: The IANA time zone identifier for the station.
  public init(
    elevation: QuantitativeValue? = nil,
    name: String,
    stationIdentifier: String,
    timeZone: String? = nil
  ) {
    self.elevation = elevation
    self.name = name
    self.stationIdentifier = stationIdentifier
    self.timeZone = timeZone
  }
}
