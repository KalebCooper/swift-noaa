/// One reported air temperature sample in GMT.
/// Missing numeric text remains observable; no measurement is inferred.
public struct AirTemperatureObservation: Codable, Hashable, Sendable {
  /// Raw flags: maximum limit, minimum limit, and rate-of-change limit, in provider order.
  public let flags: String
  /// Reported temperature in degrees Celsius in metric requests and degrees Fahrenheit in English requests; empty text means missing.
  public let temperature: TidesMeasurementValue
  /// The observation's exact GMT minute.
  public let time: TidesTimestamp

  private enum CodingKeys: String, CodingKey {
    case flags = "f"
    case temperature = "v"
    case time = "t"
  }
}
