#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// An open CO-OPS vertical datum code; station support is determined by NOAA.
/// Unknown provider values are retained; use `init(rawValue:)` or a consumer String enum.
public struct TideDatum: Codable, Hashable, RawRepresentable, Sendable {
  /// The provider's unchanged code.
  public let rawValue: String

  /// The provider's `CRD` code.
  public static let columbiaRiver = Self(rawValue: "CRD")

  /// The provider's `IGLD` code.
  public static let internationalGreatLakes = Self(rawValue: "IGLD")

  /// The provider's `LWD` code.
  public static let lowWater = Self(rawValue: "LWD")

  /// The provider's `MHHW` code.
  public static let meanHigherHighWater = Self(rawValue: "MHHW")

  /// The provider's `MHW` code.
  public static let meanHighWater = Self(rawValue: "MHW")

  /// The provider's `MLLW` code.
  public static let meanLowerLowWater = Self(rawValue: "MLLW")

  /// The provider's `MLW` code.
  public static let meanLowWater = Self(rawValue: "MLW")

  /// The provider's `MSL` code.
  public static let meanSeaLevel = Self(rawValue: "MSL")

  /// The provider's `MTL` code.
  public static let meanTideLevel = Self(rawValue: "MTL")

  /// The provider's `NAVD` code.
  public static let northAmericanVertical = Self(rawValue: "NAVD")

  /// The provider's `STND` code.
  public static let station = Self(rawValue: "STND")

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
