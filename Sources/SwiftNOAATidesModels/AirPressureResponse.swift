/// An independently decodable air pressure wire response.
public struct AirPressureResponse: Codable, Hashable, Sendable {
  /// Station metadata actually echoed by NOAA.
  public let metadata: CoastalDataMetadata
  /// Required observations in provider order, preserving empty success and missing samples.
  public let observations: [AirPressureObservation]

  private enum CodingKeys: String, CodingKey {
    case metadata
    case observations = "data"
  }
}
