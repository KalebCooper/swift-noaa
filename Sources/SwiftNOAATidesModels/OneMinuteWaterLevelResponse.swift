/// An independently decodable one-minute water-level response.
public struct OneMinuteWaterLevelResponse: Codable, Hashable, Sendable {
  /// Station metadata echoed by the provider.
  public let metadata: CoastalDataMetadata
  /// Measured observations in provider order; missing time steps are not inserted.
  public let observations: [OneMinuteWaterLevel]

  private enum CodingKeys: String, CodingKey {
    case metadata
    case observations = "data"
  }
}
