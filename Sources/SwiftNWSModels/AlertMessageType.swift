/// An extensible CAP messagetype code.
/// Unknown service values are retained in `rawValue`.
///
/// ```swift
/// let code = AlertMessageType(rawValue: "FutureCode")
/// ```
public struct AlertMessageType: Codable, Hashable, RawRepresentable, Sendable {
  /// The CAP Ack code.
  public static let ack = Self(rawValue: "Ack")

  /// The CAP Alert code.
  public static let alert = Self(rawValue: "Alert")

  /// The CAP Cancel code.
  public static let cancel = Self(rawValue: "Cancel")

  /// The CAP Error code.
  public static let error = Self(rawValue: "Error")

  /// The CAP Update code.
  public static let update = Self(rawValue: "Update")

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
