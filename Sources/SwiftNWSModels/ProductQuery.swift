#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// Filters, a time window, and a page size for the text products on `/products`.
///
/// Every filter is a list the service reads as alternatives, sent as one comma-separated
/// parameter, and an empty list leaves that filter off. Window bounds are sent as ISO 8601
/// instants in UTC with whole-second precision, and an absent bound leaves that side of the window
/// open. A nil limit omits the parameter because the route documents no default page size. The
/// route declares no cursor, so the query carries none and this package pages nothing.
///
/// The service decides which products a filter and window match and how it orders them. An
/// unfiltered query is `try ProductQuery()`.
///
/// ```swift
/// let query = try ProductQuery(limit: 2, locations: ["EWX"], types: [.areaForecastDiscussion])
/// let endpoint = Endpoint.products(matching: query)
/// ```
public struct ProductQuery: Hashable, Sendable {
  /// Why a product query could not be created.
  public enum ValidationError: Error {
    /// The requested page size is outside 1 through 500.
    case invalidLimit
  }

  /// The latest issuance instant to include, or nil for no upper bound.
  public let end: Date?
  /// The WMO identifiers of the issuing offices to include, such as `KEWX`; empty includes every
  /// office.
  public let issuingOffices: [String]
  /// The maximum number of products requested, or nil for the service's own page size.
  public let limit: Int?
  /// The product location identifiers to include, such as `EWX`; empty includes every location.
  public let locations: [String]
  /// The earliest issuance instant to include, or nil for no lower bound.
  public let start: Date?
  /// The product codes to include; empty includes every kind of product.
  public let types: [ProductCode]
  /// The WMO collective identifiers to include, such as `FXUS64`; empty includes every collective.
  public let wmoCollectiveIdentifiers: [String]

  /// Creates a validated product query without sending it.
  /// - Parameters:
  ///   - end: The latest issuance instant to include.
  ///   - issuingOffices: The WMO identifiers of the issuing offices to include.
  ///   - limit: A page size from 1 through 500, or nil for the service's own page size.
  ///   - locations: The product location identifiers to include.
  ///   - start: The earliest issuance instant to include.
  ///   - types: The product codes to include.
  ///   - wmoCollectiveIdentifiers: The WMO collective identifiers to include.
  /// - Throws: ``ValidationError/invalidLimit`` for an unsupported page size.
  public init(
    end: Date? = nil, issuingOffices: [String] = [], limit: Int? = nil, locations: [String] = [],
    start: Date? = nil, types: [ProductCode] = [], wmoCollectiveIdentifiers: [String] = []
  ) throws(ValidationError) {
    if let limit { guard (1...500).contains(limit) else { throw .invalidLimit } }
    self.end = end
    self.issuingOffices = issuingOffices
    self.limit = limit
    self.locations = locations
    self.start = start
    self.types = types
    self.wmoCollectiveIdentifiers = wmoCollectiveIdentifiers
  }

  var query: String {
    var values: [String: String] = [:]
    func add(_ key: String, _ items: [String]) {
      if !items.isEmpty { values[key] = items.joined(separator: ",") }
    }
    if let end { values["end"] = end.formatted(.iso8601) }
    if let limit { values["limit"] = String(limit) }
    add("location", locations)
    add("office", issuingOffices)
    if let start { values["start"] = start.formatted(.iso8601) }
    add("type", types.map(\.rawValue))
    add("wmoid", wmoCollectiveIdentifiers)
    return URLComponents.nwsQuery(
      values.keys.sorted().map { URLQueryItem(name: $0, value: values[$0]) })
  }
}
