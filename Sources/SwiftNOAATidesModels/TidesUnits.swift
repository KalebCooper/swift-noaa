#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// An open CO-OPS unit system; values are never converted while decoding.
/// Unknown provider values are retained; use `init(rawValue:)` or a consumer String enum.
public struct TidesUnits: Codable, Hashable, RawRepresentable, Sendable {
  /// The provider's unchanged code.
  public let rawValue: String

  /// The provider's `english` code.
  public static let english = Self(rawValue: "english")

  /// The provider's `metric` code.
  public static let metric = Self(rawValue: "metric")

  /// Creates a value without restricting the provider vocabulary.
  /// - Parameter rawValue: The exact provider code.
  public init(rawValue: String) { self.rawValue = rawValue }

  /// Creates a value from a consumer-defined String enum.
  /// - Parameter code: The provider code.
  public init<Code>(_ code: Code) where Code: RawRepresentable, Code.RawValue == String {
    self.init(rawValue: code.rawValue)
  }

  /// Decodes the raw provider string.
  public init(from decoder: any Decoder) throws {
    self.init(rawValue: try decoder.singleValueContainer().decode(String.self))
  }

  /// Encodes the raw provider string.
  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(rawValue)
  }
}
