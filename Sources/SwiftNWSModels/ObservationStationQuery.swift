#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// Filters and an initial cursor for the observation-station directory.
/// Empty identifier and state arrays omit those restrictions.
///
/// ```swift
/// let query = try ObservationStationQuery(identifiers: ["KATT"], limit: 100, states: [.texas])
/// let endpoint = Endpoint.observationStations(matching: query)
/// ```
public struct ObservationStationQuery: Hashable, Sendable {
  /// Why a station query could not be created.
  public enum ValidationError: Error {
    /// The requested page size is outside 1 through 500.
    case invalidLimit
  }

  /// An opaque initial cursor, or nil to start at the first page.
  public let cursor: String?
  /// Station identifiers to include, in the supplied order.
  public let identifiers: [String]
  /// The maximum number of stations requested per page.
  public let limit: Int
  /// State or territory codes to include; the service validates their vocabulary.
  public let states: [AreaCode]

  /// Creates a validated station-directory query without sending it.
  /// - Parameters:
  ///   - cursor: An opaque initial cursor.
  ///   - identifiers: Station identifiers, or an empty array for all identifiers.
  ///   - limit: A page size from 1 through 500.
  ///   - states: State or territory codes, or an empty array for all states.
  /// - Throws: ``ValidationError/invalidLimit`` for an unsupported page size.
  public init(
    cursor: String? = nil, identifiers: [String] = [], limit: Int = 500, states: [AreaCode] = []
  ) throws(ValidationError) {
    guard (1...500).contains(limit) else { throw .invalidLimit }
    self.cursor = cursor
    self.identifiers = identifiers
    self.limit = limit
    self.states = states
  }

  var query: String {
    var items: [URLQueryItem] = []
    if let cursor { items.append(URLQueryItem(name: "cursor", value: cursor)) }
    if !identifiers.isEmpty {
      items.append(URLQueryItem(name: "id", value: identifiers.joined(separator: ",")))
    }
    items.append(URLQueryItem(name: "limit", value: String(limit)))
    if !states.isEmpty {
      items.append(
        URLQueryItem(name: "state", value: states.map(\.rawValue).joined(separator: ",")))
    }
    return URLComponents.nwsQuery(items)
  }
}
