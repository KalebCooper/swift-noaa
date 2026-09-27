#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// An open event code for verified observed extrema, preserving exact provider text.
/// Unknown provider values are retained; use `init(rawValue:)` or a consumer String enum.
public struct ObservedHighLowWaterLevelKind: Codable, Hashable, RawRepresentable, Sendable {
  /// The provider's unchanged code.
  public let rawValue: String

  /// Recognized event meanings; classification does not change the raw code or equality.
  public enum Classification: String, Codable, Sendable {
    case high
    case higherHigh
    case low
    case lowerLow
  }

  /// Interprets documented codes and recorded single-space padding, or nil for an unfamiliar code.
  public var classification: Classification? {
    switch rawValue {
    case "H", "H ": .high
    case "HH": .higherHigh
    case "L", "L ": .low
    case "LL": .lowerLow
    default: nil
    }
  }

  /// Canonical high-water code. Recorded padded forms retain a distinct raw value.
  public static let high = Self(rawValue: "H")
  /// Higher high water.
  public static let higherHigh = Self(rawValue: "HH")
  /// Canonical low-water code. Recorded padded forms retain a distinct raw value.
  public static let low = Self(rawValue: "L")
  /// Lower low water.
  public static let lowerLow = Self(rawValue: "LL")

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
