#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// A metadata resource reference, which does not guarantee data availability.
public struct CoastalResource: Codable, Equatable, Sendable {
  /// The provider link, retained as text without fetching.
  public let url: String?

  private enum CodingKeys: String, CodingKey {
    case url = "self"
  }
}

/// A station directory or detail envelope, preserving provider order and reported count.
public struct CoastalStations: Codable, Equatable, Sendable {
  /// The count reported by the provider.
  public let count: Int
  /// Stations in the original order, without sorting or deduplication.
  public let stations: [CoastalStation]
  /// The reported units, including nil when the API sends null.
  public let units: String?
  /// The response's self link, retained without fetching.
  public let url: String?

  private enum CodingKeys: String, CodingKey {
    case count
    case stations
    case units
    case url = "self"
  }
}
