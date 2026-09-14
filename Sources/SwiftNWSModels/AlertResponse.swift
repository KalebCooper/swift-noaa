/// An extensible CAP recommended-response code.
///
/// Known values match the live NWS schema. Unknown service values remain available in ``rawValue``.
public struct AlertResponse: Codable, Hashable, RawRepresentable, Sendable {
  /// The event no longer poses a threat.
  public static let allClear = Self(rawValue: "AllClear")

  /// Evaluate the information in this message.
  public static let assess = Self(rawValue: "Assess")

  /// Avoid the subject event as instructed.
  public static let avoid = Self(rawValue: "Avoid")

  /// Relocate from the described location.
  public static let evacuate = Self(rawValue: "Evacuate")

  /// Execute a predefined plan.
  public static let execute = Self(rawValue: "Execute")

  /// Attend to information sources.
  public static let monitor = Self(rawValue: "Monitor")

  /// No action is recommended.
  public static let none = Self(rawValue: "None")

  /// Make preparations according to the instructions.
  public static let prepare = Self(rawValue: "Prepare")

  /// Take shelter in place or as instructed.
  public static let shelter = Self(rawValue: "Shelter")

  /// The service's exact code.
  public let rawValue: String

  /// Creates a code from a consumer-defined String-backed value.
  public init<Value>(_ value: Value) where Value: RawRepresentable, Value.RawValue == String {
    self.init(rawValue: value.rawValue)
  }

  /// Creates a code without restricting future service values.
  public init(rawValue: String) { self.rawValue = rawValue }

  /// Decodes the exact service code.
  public init(from decoder: any Decoder) throws {
    rawValue = try decoder.singleValueContainer().decode(String.self)
  }

  /// Encodes the exact service code.
  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(rawValue)
  }
}
