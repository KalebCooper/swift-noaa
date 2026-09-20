#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// A forecast, county, fire weather, or marine zone, as `/zones/{type}/{zoneId}` describes it or a
/// zone collection lists it.
///
/// The identifier, name, and reported type are always present. Every other field is optional
/// because the service omits or nulls some of them for some zones: a marine zone has a `null`
/// state, and a county zone can list no observation stations. Values are kept as the service sends
/// them, including an empty state code, a far-future expiration date, and the office fields the
/// service has deprecated but still sends. Dates decode as ISO 8601 independently of the decoder's
/// date strategy.
///
/// ```swift
/// let zone = try JSONDecoder().decode(Feature<WeatherZone>.self, from: body).properties
/// print(zone.id, zone.type.rawValue, zone.name)  // "TXZ192 public Travis"
/// ```
public struct WeatherZone: Codable, Hashable, Sendable {
  /// The AWIPS location identifier of the responsible office, such as `EWX`.
  public var awipsLocationIdentifier: String?

  /// The county warning area identifiers, which the service has deprecated but still sends.
  public var cwa: [String]?

  /// When this definition of the zone took effect.
  public var effectiveDate: Date?

  /// When this definition of the zone expires; the service sends a far-future date for a current
  /// definition.
  public var expirationDate: Date?

  /// A link to the responsible forecast office.
  public var forecastOffice: URL?

  /// Links to the responsible forecast offices, which the service has deprecated but still sends.
  public var forecastOffices: [URL]?

  /// The forecast grid identifier of the responsible office, such as `EWX`.
  public var gridIdentifier: String?

  /// The zone's identifier, such as `TXZ192`.
  public var id: String

  /// The zone's name, such as `Travis`.
  public var name: String

  /// Links to the observation stations in the zone, in the order the service listed them.
  public var observationStations: [URL]?

  /// The identifier of the radar station covering the zone, or nil when the service reports none.
  public var radarStation: String?

  /// The state or territory the zone is in; nil for a marine zone, and an empty code when the
  /// service sends an empty string.
  public var state: AreaCode?

  /// The IANA time zone identifiers the zone spans.
  public var timeZone: [String]?

  /// The zone's reported type, which can differ from the route it was requested through.
  public var type: ZoneType

  /// Creates a zone.
  ///
  /// - Parameters:
  ///   - awipsLocationIdentifier: The AWIPS location identifier of the responsible office.
  ///   - cwa: The county warning area identifiers.
  ///   - effectiveDate: When this definition of the zone took effect.
  ///   - expirationDate: When this definition of the zone expires.
  ///   - forecastOffice: A link to the responsible forecast office.
  ///   - forecastOffices: Links to the responsible forecast offices.
  ///   - gridIdentifier: The forecast grid identifier of the responsible office.
  ///   - id: The zone's identifier.
  ///   - name: The zone's name.
  ///   - observationStations: Links to the observation stations in the zone.
  ///   - radarStation: The identifier of the radar station covering the zone.
  ///   - state: The state or territory the zone is in.
  ///   - timeZone: The IANA time zone identifiers the zone spans.
  ///   - type: The zone's reported type.
  public init(
    awipsLocationIdentifier: String? = nil,
    cwa: [String]? = nil,
    effectiveDate: Date? = nil,
    expirationDate: Date? = nil,
    forecastOffice: URL? = nil,
    forecastOffices: [URL]? = nil,
    gridIdentifier: String? = nil,
    id: String,
    name: String,
    observationStations: [URL]? = nil,
    radarStation: String? = nil,
    state: AreaCode? = nil,
    timeZone: [String]? = nil,
    type: ZoneType
  ) {
    self.awipsLocationIdentifier = awipsLocationIdentifier
    self.cwa = cwa
    self.effectiveDate = effectiveDate
    self.expirationDate = expirationDate
    self.forecastOffice = forecastOffice
    self.forecastOffices = forecastOffices
    self.gridIdentifier = gridIdentifier
    self.id = id
    self.name = name
    self.observationStations = observationStations
    self.radarStation = radarStation
    self.state = state
    self.timeZone = timeZone
    self.type = type
  }

  /// Decodes a zone, reading its dates as ISO 8601 text.
  /// - Parameter decoder: The decoder to read.
  /// - Throws: `DecodingError` for a missing identity field or a date that is not ISO 8601.
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.init(
      awipsLocationIdentifier: try container.decodeIfPresent(
        String.self, forKey: .awipsLocationIdentifier),
      cwa: try container.decodeIfPresent([String].self, forKey: .cwa),
      effectiveDate: try container.decodeISO8601IfPresent(forKey: .effectiveDate),
      expirationDate: try container.decodeISO8601IfPresent(forKey: .expirationDate),
      forecastOffice: try container.decodeIfPresent(URL.self, forKey: .forecastOffice),
      forecastOffices: try container.decodeIfPresent([URL].self, forKey: .forecastOffices),
      gridIdentifier: try container.decodeIfPresent(String.self, forKey: .gridIdentifier),
      id: try container.decode(String.self, forKey: .id),
      name: try container.decode(String.self, forKey: .name),
      observationStations: try container.decodeIfPresent([URL].self, forKey: .observationStations),
      radarStation: try container.decodeIfPresent(String.self, forKey: .radarStation),
      state: try container.decodeIfPresent(AreaCode.self, forKey: .state),
      timeZone: try container.decodeIfPresent([String].self, forKey: .timeZone),
      type: try container.decode(ZoneType.self, forKey: .type)
    )
  }

  /// Encodes the zone, writing its dates as ISO 8601 text.
  /// - Parameter encoder: The encoder to write.
  /// - Throws: Any error from the encoder.
  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encodeIfPresent(awipsLocationIdentifier, forKey: .awipsLocationIdentifier)
    try container.encodeIfPresent(cwa, forKey: .cwa)
    try container.encodeIfPresent(
      effectiveDate?.formatted(Date.ISO8601FormatStyle(includingFractionalSeconds: true)),
      forKey: .effectiveDate)
    try container.encodeIfPresent(
      expirationDate?.formatted(Date.ISO8601FormatStyle(includingFractionalSeconds: true)),
      forKey: .expirationDate)
    try container.encodeIfPresent(forecastOffice, forKey: .forecastOffice)
    try container.encodeIfPresent(forecastOffices, forKey: .forecastOffices)
    try container.encodeIfPresent(gridIdentifier, forKey: .gridIdentifier)
    try container.encode(id, forKey: .id)
    try container.encode(name, forKey: .name)
    try container.encodeIfPresent(observationStations, forKey: .observationStations)
    try container.encodeIfPresent(radarStation, forKey: .radarStation)
    try container.encodeIfPresent(state, forKey: .state)
    try container.encodeIfPresent(timeZone, forKey: .timeZone)
    try container.encode(type, forKey: .type)
  }

  private enum CodingKeys: String, CodingKey {
    case awipsLocationIdentifier
    case cwa
    case effectiveDate
    case expirationDate
    case forecastOffice
    case forecastOffices
    case gridIdentifier
    case id
    case name
    case observationStations
    case radarStation
    case state
    case timeZone
    case type
  }
}
