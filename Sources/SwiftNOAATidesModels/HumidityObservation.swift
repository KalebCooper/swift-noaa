/// One reported humidity sample in GMT.
/// Missing numeric text remains observable; no measurement is inferred.
public struct HumidityObservation: Codable, Hashable, Sendable {
  /// Raw flags: maximum limit, minimum limit, and rate-of-change limit, in provider order.
  public let flags: String
  /// Reported humidity in percent relative humidity in both metric and English requests; empty text means missing.
  public let humidity: TidesMeasurementValue
  /// The observation's exact GMT minute.
  public let time: TidesTimestamp

  private enum CodingKeys: String, CodingKey {
    case flags = "f"
    case humidity = "v"
    case time = "t"
  }
}
