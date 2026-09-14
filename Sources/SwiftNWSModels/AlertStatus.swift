/// An extensible CAP status code.
/// Unknown service values are retained in `rawValue`.
///
/// ```swift
/// let code = AlertStatus(rawValue: "FutureCode")
/// ```
public struct AlertStatus: Codable, Hashable, RawRepresentable, Sendable {
  /// The CAP Actual code.
  public static let actual = Self(rawValue: "Actual")

  /// The CAP Draft code.
  public static let draft = Self(rawValue: "Draft")

  /// The CAP Exercise code.
  public static let exercise = Self(rawValue: "Exercise")

  /// The CAP System code.
  public static let system = Self(rawValue: "System")

  /// The CAP Test code.
  public static let test = Self(rawValue: "Test")

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
