/// One reported visibility sample in GMT.
/// Missing numeric text remains observable; no measurement is inferred.
public struct VisibilityObservation: Codable, Hashable, Sendable {
  /// Raw flags: maximum limit, minimum limit, and rate-of-change limit, in provider order.
  public let flags: String
  /// The observation's exact GMT minute.
  public let time: TidesTimestamp
  /// Reported visibility in kilometers in metric requests and nautical miles in English requests; empty text means missing.
  public let visibility: TidesMeasurementValue

  private enum CodingKeys: String, CodingKey {
    case flags = "f"
    case time = "t"
    case visibility = "v"
  }
}
