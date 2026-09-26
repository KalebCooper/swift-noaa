/// An independently decodable verified hourly-height envelope.
public struct HourlyWaterLevelResponse: Codable, Hashable, Sendable {
  /// Provider-reported station metadata.
  public let metadata: CoastalDataMetadata
  /// Reported hourly observations in provider order, without filling gaps.
  public let observations: [HourlyWaterLevel]

  private enum CodingKeys: String, CodingKey {
    case metadata
    case observations = "data"
  }
}
