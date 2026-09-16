#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// The unvalidated continuation metadata included with a paginated collection.
///
/// The next-page value remains a raw optional string so decoding preserves malformed or incomplete
/// provider metadata for an executor to report as a pagination failure.
///
/// ```swift
/// if let pagination = page.pagination {
///   let next = try pagination.nextEndpoint(after: endpoint)
/// }
/// ```
public struct PaginationInfo: Codable, Hashable, Sendable {
  /// The raw link to the next page, or nil when the metadata omits it.
  public var next: String?

  /// Creates pagination metadata without validating or following its next-page value.
  /// - Parameter next: The raw next-page link, or nil when it is missing.
  public init(next: String? = nil) {
    self.next = next
  }

  /// Validates the continuation and preserves the endpoint's representation headers.
  /// - Parameter endpoint: The endpoint whose response provided this metadata.
  /// - Returns: The next endpoint with the provider's encoded path and query unchanged.
  /// - Throws: ``NWSPaginationError`` when the next value is missing or not an allowed API URL.
  public func nextEndpoint<Response>(after endpoint: Endpoint<Response>)
    throws(NWSPaginationError) -> Endpoint<Response>
  {
    guard let raw = next else { throw .missingNext }
    guard let url = URL(string: raw, encodingInvalidCharacters: false),
      let next = Endpoint<Response>(
        accept: endpoint.accept, featureFlags: endpoint.featureFlags, link: url)
    else { throw .invalidNext(raw) }
    return next
  }
}
