/// One reported conductivity sample in GMT.
/// Missing numeric text remains observable; no measurement is inferred.
public struct ConductivityObservation: Codable, Hashable, Sendable {
  /// Reported conductivity in millisiemens per centimeter in both metric and English requests; empty text means missing.
  public let conductivity: TidesMeasurementValue
  /// Raw flags: maximum limit, minimum limit, and rate-of-change limit, in provider order.
  public let flags: String
  /// The observation's exact GMT minute.
  public let time: TidesTimestamp

  private enum CodingKeys: String, CodingKey {
    case conductivity = "v"
    case flags = "f"
    case time = "t"
  }
}
