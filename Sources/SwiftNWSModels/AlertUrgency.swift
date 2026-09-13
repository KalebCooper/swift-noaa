/// An extensible CAP urgency code.
/// Unknown service values are retained in `rawValue`.
///
/// ```swift
/// let code = AlertUrgency(rawValue: "FutureCode")
/// ```
public struct AlertUrgency: Codable, Hashable, RawRepresentable, Sendable {
  /// The CAP Expected code.
  public static let expected = Self(rawValue: "Expected")

  /// The CAP Future code.
  public static let future = Self(rawValue: "Future")

  /// The CAP Immediate code.
  public static let immediate = Self(rawValue: "Immediate")

  /// The CAP Past code.
  public static let past = Self(rawValue: "Past")

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
