#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// An open Metadata API station directory category.
/// Unknown provider values are retained; use `init(rawValue:)` or a consumer String enum.
public struct CoastalStationType: Codable, Hashable, RawRepresentable, Sendable {
  /// The provider's unchanged code.
  public let rawValue: String

  /// The provider's `cond` directory category.
  public static let conductivity = Self(rawValue: "cond")

  /// The provider's `currentpredictions` directory category.
  public static let currentPredictions = Self(rawValue: "currentpredictions")

  /// The provider's `currents` directory category.
  public static let currents = Self(rawValue: "currents")

  /// The provider's `historiccurrents` directory category.
  public static let historicCurrents = Self(rawValue: "historiccurrents")

  /// The provider's `met` directory category.
  public static let meteorological = Self(rawValue: "met")

  /// The provider's `1minute` directory category.
  public static let oneMinuteWaterLevels = Self(rawValue: "1minute")

  /// The provider's `physocean` directory category.
  public static let physicalOceanography = Self(rawValue: "physocean")

  /// The provider's `surveycurrents` directory category.
  public static let surveyCurrents = Self(rawValue: "surveycurrents")

  /// The provider's `tidepredictions` code.
  public static let tidePredictions = Self(rawValue: "tidepredictions")

  /// The provider's `visibility` directory category.
  public static let visibility = Self(rawValue: "visibility")

  /// The provider's `waterlevels` code.
  public static let waterLevels = Self(rawValue: "waterlevels")

  /// The provider's `waterlevelsandmet` directory category.
  public static let waterLevelsAndMeteorological = Self(rawValue: "waterlevelsandmet")

  /// The provider's `watertemp` directory category.
  public static let waterTemperature = Self(rawValue: "watertemp")

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
