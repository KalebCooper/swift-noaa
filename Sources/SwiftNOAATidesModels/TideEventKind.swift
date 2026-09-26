#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// An open predicted tide event code, preserving unknown provider kinds.
/// Unknown provider values are retained; use `init(rawValue:)` or a consumer String enum.
public struct TideEventKind: Codable, Hashable, RawRepresentable, Sendable {
  /// The provider's unchanged code.
  public let rawValue: String

  /// The provider's `H` code.
  public static let high = Self(rawValue: "H")

  /// The provider's `L` code.
  public static let low = Self(rawValue: "L")

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
