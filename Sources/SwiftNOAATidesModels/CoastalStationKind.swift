#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// An open reference or subordinate station classification.
/// Unknown provider values are retained; use `init(rawValue:)` or a consumer String enum.
public struct CoastalStationKind: Codable, Hashable, RawRepresentable, Sendable {
  /// The provider's unchanged code.
  public let rawValue: String

  /// The provider's `R` code.
  public static let reference = Self(rawValue: "R")

  /// The provider's `S` code.
  public static let subordinate = Self(rawValue: "S")

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
