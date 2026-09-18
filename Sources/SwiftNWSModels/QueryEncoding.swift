#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

extension URLComponents {
  /// Encodes query items as the `?`-prefixed query of an endpoint path, or an empty string.
  ///
  /// A literal plus sign is percent-encoded so a cursor containing one is not read as a space.
  static func nwsQuery(_ items: [URLQueryItem]) -> String {
    guard !items.isEmpty else { return "" }
    var components = URLComponents()
    components.queryItems = items
    return components.percentEncodedQuery.map {
      "?" + $0.split(separator: "+", omittingEmptySubsequences: false).joined(separator: "%2B")
    } ?? ""
  }
}
