/// A watch, warning, or advisory in effect in raw forecast grid data.
///
/// The codes are P-VTEC phenomenon and significance codes as NWS Directive 10-1703 defines them,
/// such as `FA` and `A` for a flood watch. They are kept as the service sends them, without
/// validation or translation. An empty hazards layer is the normal answer when nothing is in effect.
///
/// ```swift
/// for entry in grid.hazards?.values ?? [] {
///   for hazard in entry.value {
///     print(hazard.phenomenon + "." + hazard.significance, entry.validTime.start)
///   }
/// }
/// ```
public struct ForecastHazard: Codable, Hashable, Sendable {
  /// The sequence number of a national or regional center product, such as a Storm Prediction
  /// Center watch, or `nil` when the hazard refers to none.
  public var eventNumber: Int?

  /// The P-VTEC phenomenon code, such as `FA`.
  public var phenomenon: String

  /// The P-VTEC significance code, such as `A` for a watch or `Y` for an advisory.
  public var significance: String

  /// Creates a hazard.
  ///
  /// - Parameters:
  ///   - eventNumber: The center product's sequence number, or `nil`.
  ///   - phenomenon: The P-VTEC phenomenon code.
  ///   - significance: The P-VTEC significance code.
  public init(eventNumber: Int? = nil, phenomenon: String, significance: String) {
    self.eventNumber = eventNumber
    self.phenomenon = phenomenon
    self.significance = significance
  }

  /// Decodes a hazard, treating a `null` event number as `nil`.
  /// - Parameter decoder: The decoder to read.
  /// - Throws: `DecodingError` when a code is missing or malformed.
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.init(
      eventNumber: try container.decodeIfPresent(Int.self, forKey: .eventNumber),
      phenomenon: try container.decode(String.self, forKey: .phenomenon),
      significance: try container.decode(String.self, forKey: .significance))
  }

  /// Encodes the service's shape, writing `null` for a missing event number.
  /// - Parameter encoder: The encoder to write.
  /// - Throws: Any error from the encoder.
  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(eventNumber, forKey: .eventNumber)
    try container.encode(phenomenon, forKey: .phenomenon)
    try container.encode(significance, forKey: .significance)
  }

  private enum CodingKeys: String, CodingKey {
    case eventNumber = "event_number"
    case phenomenon
    case significance
  }
}
