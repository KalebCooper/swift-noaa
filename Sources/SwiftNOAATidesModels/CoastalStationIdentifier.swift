#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// A validated station identifier without a fixed length or numeric-only assumption.
///
/// The spelling is retained. For example, `try CoastalStationIdentifier("cb0102")`.
public struct CoastalStationIdentifier: Hashable, Sendable {
  /// The provider identifier, unchanged.
  public let rawValue: String

  /// Creates a nonempty ASCII alphanumeric identifier, also allowing hyphens and underscores.
  /// - Parameter rawValue: The provider's station identifier.
  /// - Throws: `TidesQueryError.invalidStationIdentifier` for unusable text.
  public init(_ rawValue: String) throws(TidesQueryError) {
    guard !rawValue.isEmpty,
      rawValue.utf8.allSatisfy({
        (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0) || $0 == 45
          || $0 == 95
      })
    else { throw .invalidStationIdentifier(rawValue) }
    self.rawValue = rawValue
  }
}
