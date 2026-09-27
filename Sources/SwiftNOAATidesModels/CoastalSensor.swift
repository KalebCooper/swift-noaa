/// An installed sensor and its reported status, not a guarantee of available observations.
public struct CoastalSensor: Codable, Hashable, Sendable {
  /// The reported data collection platform number.
  public let dataCollectionPlatform: Int?
  /// Elevation in the enclosing response's reported units, absent when unavailable.
  public let elevation: Double?
  /// The exact sensor identifier.
  public let identifier: String
  /// Provider outage or status text, including an empty string.
  public let message: String?
  /// The provider's sensor name.
  public let name: String
  /// Elevation reference text; an empty string remains empty.
  public let referenceDatum: String?
  /// The open integer status code.
  public let status: CoastalSensorStatus

  private enum CodingKeys: String, CodingKey {
    case dataCollectionPlatform = "dcp"
    case elevation
    case identifier = "sensorID"
    case message
    case name
    case referenceDatum = "refdatum"
    case status
  }
}
