/// A media type the National Weather Service API answers with.
///
/// Every endpoint names the representation it wants in its `Accept` header. The API's default is
/// GeoJSON, and most endpoints offer one or more alternatives.
///
/// ```swift
/// let accept = MediaType.geoJSON.rawValue  // "application/geo+json"
/// ```
public struct MediaType: Hashable, RawRepresentable, Sendable {
  /// The media type as it is written in a header field, such as `application/geo+json`.
  public let rawValue: String

  /// Creates a media type from the string written in a header field.
  ///
  /// - Parameter rawValue: The media type, such as `application/geo+json`.
  public init(rawValue: String) {
    self.rawValue = rawValue
  }
}

extension MediaType {
  /// GeoJSON, `application/geo+json`, the API's default representation.
  public static let geoJSON = MediaType(rawValue: "application/geo+json")

  /// JSON-LD, `application/ld+json`, the only representation of some endpoints, such as
  /// `/alerts/active/count` and `/alerts/types`.
  public static let jsonLD = MediaType(rawValue: "application/ld+json")
}
