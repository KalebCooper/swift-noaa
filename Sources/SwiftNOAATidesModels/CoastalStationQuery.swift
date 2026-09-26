#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// A single directory response selected by station type, without resource expansion or pagination.
public struct CoastalStationQuery: Hashable, Sendable {
  /// The directory category, which does not guarantee support for a particular data query.
  public let type: CoastalStationType

  /// Creates a directory query.
  /// - Parameter type: A provider category, including a consumer-defined value.
  /// - Throws: `TidesQueryError.invalidStationType` for empty text or controls.
  public init(type: CoastalStationType) throws(TidesQueryError) {
    guard !type.rawValue.isEmpty,
      !type.rawValue.unicodeScalars.contains(where: { $0.properties.generalCategory == .control })
    else { throw .invalidStationType(type.rawValue) }
    self.type = type
  }

  /// Creates a query using a consumer's String-backed category.
  /// - Parameter type: A provider category.
  /// - Throws: `TidesQueryError.invalidStationType` for empty text or controls.
  public init<Code>(type: Code) throws(TidesQueryError)
  where Code: RawRepresentable, Code.RawValue == String {
    try self.init(type: CoastalStationType(type))
  }
}
