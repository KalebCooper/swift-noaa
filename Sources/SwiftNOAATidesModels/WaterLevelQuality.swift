#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// An open provider quality code for six-minute measured water levels.
/// Unknown provider values are retained; use `init(rawValue:)` or a consumer String enum.
public struct WaterLevelQuality: Codable, Hashable, RawRepresentable, Sendable {
  /// The provider's unchanged code.
  public let rawValue: String

  /// Preliminary data, as reported by the provider.
  public static let preliminary = Self(rawValue: "p")

  /// Verified data, as reported by the provider.
  public static let verified = Self(rawValue: "v")

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
