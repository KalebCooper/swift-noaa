/// Installed sensors and reported elevation units from `sensors(stationIdentifier:units:)`.
public struct CoastalSensors: Codable, Hashable, Sendable {
  /// Resource link text, never fetched automatically.
  public let selfLink: String?
  /// Required nullable table: nil preserves NOAA's null, distinct from an empty array.
  public let sensors: [CoastalSensor]?
  /// Provider-reported elevation units, separate from the requested unit-system code.
  public let units: String?

  private enum CodingKeys: String, CodingKey {
    case selfLink = "self"
    case sensors
    case units
  }

  /// Decodes the required table while retaining explicit null.
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.selfLink = try container.decodeIfPresent(String.self, forKey: .selfLink)
    self.sensors = try container.decode([CoastalSensor]?.self, forKey: .sensors)
    self.units = try container.decodeIfPresent(String.self, forKey: .units)
  }

  /// Encodes an absent table as explicit null, preserving the required field.
  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encodeIfPresent(selfLink, forKey: .selfLink)
    try container.encode(sensors, forKey: .sensors)
    try container.encodeIfPresent(units, forKey: .units)
  }
}
