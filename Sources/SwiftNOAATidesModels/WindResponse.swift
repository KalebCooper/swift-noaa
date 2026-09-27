/// An independently decodable wind wire response.
public struct WindResponse: Codable, Hashable, Sendable {
  /// Station metadata actually echoed by NOAA.
  public let metadata: CoastalDataMetadata
  /// Required observations in provider order, preserving empty success and missing samples.
  public let observations: [WindObservation]

  private enum CodingKeys: String, CodingKey {
    case metadata
    case observations = "data"
  }
}
