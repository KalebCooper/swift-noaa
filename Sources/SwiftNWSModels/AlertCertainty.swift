/// An extensible CAP certainty code.
/// Unknown service values are retained in `rawValue`.
///
/// ```swift
/// let code = AlertCertainty(rawValue: "FutureCode")
/// ```
public struct AlertCertainty: Codable, Hashable, RawRepresentable, Sendable {
  /// The CAP Likely code.
  public static let likely = Self(rawValue: "Likely")

  /// The CAP Observed code.
  public static let observed = Self(rawValue: "Observed")

  /// The CAP Possible code.
  public static let possible = Self(rawValue: "Possible")

  /// The CAP Unknown code.
  public static let unknown = Self(rawValue: "Unknown")

  /// The CAP Unlikely code.
  public static let unlikely = Self(rawValue: "Unlikely")

  /// The service's exact code.
  public let rawValue: String

  /// Creates a code from a consumer-defined String-backed value.
  /// - Parameter value: The value whose raw string to retain.
  public init<Value>(_ value: Value) where Value: RawRepresentable, Value.RawValue == String {
    self.init(rawValue: value.rawValue)
  }

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
