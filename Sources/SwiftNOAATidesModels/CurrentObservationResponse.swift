/// An independently decodable measured-current envelope.
public struct CurrentObservationResponse: Codable, Hashable, Sendable {
  /// Provider-reported station metadata.
  public let metadata: CoastalDataMetadata
  /// Reported current observations in provider order, without filling gaps.
  public let observations: [CurrentObservation]

  private enum CodingKeys: String, CodingKey {
    case metadata
    case observations = "data"
  }
}
