/// An extensible CAP severity code.
/// Unknown service values are retained in `rawValue`.
///
/// ```swift
/// let code = AlertSeverity(rawValue: "FutureCode")
/// ```
public struct AlertSeverity: Codable, Hashable, RawRepresentable, Sendable {
  /// The CAP Extreme code.
  public static let extreme = Self(rawValue: "Extreme")

  /// The CAP Minor code.
  public static let minor = Self(rawValue: "Minor")

  /// The CAP Moderate code.
  public static let moderate = Self(rawValue: "Moderate")

  /// The CAP Severe code.
  public static let severe = Self(rawValue: "Severe")

  /// The CAP Unknown code.
  public static let unknown = Self(rawValue: "Unknown")

  /// The service's exact code.
  public let rawValue: String

  /// Creates a code without restricting future service values.
  /// - Parameter rawValue: The exact code.
  public init(rawValue: String) { self.rawValue = rawValue }

  /// Decodes the exact service code.
  /// - Parameter decoder: The decoder to read.
  /// - Throws: `DecodingError` for a non-string value.
  public init(from decoder: any Decoder) throws {
    rawValue = try decoder.singleValueContainer().decode(String.self)
  }

  /// Encodes the exact service code.
  /// - Parameter encoder: The encoder to write.
  /// - Throws: Any error from the encoder.
  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(rawValue)
  }
}
