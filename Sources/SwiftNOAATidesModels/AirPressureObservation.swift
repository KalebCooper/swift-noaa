/// One reported air pressure sample in GMT.
/// Missing numeric text remains observable; no measurement is inferred.
public struct AirPressureObservation: Codable, Hashable, Sendable {
  /// Raw flags: maximum limit, minimum limit, and rate-of-change limit, in provider order.
  public let flags: String
  /// Reported pressure in millibars in both metric and English requests; empty text means missing.
  public let pressure: TidesMeasurementValue
  /// The observation's exact GMT minute.
  public let time: TidesTimestamp

  private enum CodingKeys: String, CodingKey {
    case flags = "f"
    case pressure = "v"
    case time = "t"
  }
}
