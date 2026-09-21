/// The locations a product catalog lists, from `/products/locations` and
/// `/products/types/{typeId}/locations`.
///
/// Each key is a location identifier the product routes take as a path segment, such as an office
/// or site code, and each value is the description the service published for it. The service
/// describes only some of the locations in the whole catalog and sends `null` for the rest; an
/// undescribed location is kept with a nil value rather than dropped, because its identifier is
/// usable on the product routes either way. A body without a `locations` object fails to decode
/// rather than producing an empty catalog.
///
/// The routes document no page size or cursor, so this package offers no location pagination,
/// ordering policy, or filtering.
///
/// ```swift
/// let locations = try await weather.productLocations(for: .areaForecastDiscussion)
/// print(locations.locations["EWX"] ?? nil)  // "Austin/San Antonio, TX"
/// ```
public struct ProductLocations: Codable, Hashable, Sendable {
  /// The locations, keyed by identifier, each with the description the service published for it
  /// or nil when the service described it as `null`.
  public var locations: [String: String?]

  /// Creates a location catalog.
  ///
  /// - Parameter locations: The locations, keyed by identifier. A nil value is a location the
  ///   service listed without a description.
  public init(locations: [String: String?]) {
    self.locations = locations
  }

  /// Decodes the catalog, keeping every location the service listed without a description.
  ///
  /// - Parameter decoder: The decoder to read the body from.
  /// - Throws: `DecodingError` when the body has no `locations` object, or when a location's
  ///   description is neither a string nor `null`.
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let described = try container.nestedContainer(keyedBy: LocationKey.self, forKey: .locations)
    var locations: [String: String?] = [:]
    locations.reserveCapacity(described.allKeys.count)
    for key in described.allKeys {
      if try described.decodeNil(forKey: key) {
        locations.updateValue(nil, forKey: key.stringValue)
      } else {
        locations[key.stringValue] = try described.decode(String.self, forKey: key)
      }
    }
    self.locations = locations
  }

  /// Encodes the catalog, writing an undescribed location as `null`.
  ///
  /// - Parameter encoder: The encoder to write the body to.
  /// - Throws: Whatever the encoder throws.
  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    var described = container.nestedContainer(keyedBy: LocationKey.self, forKey: .locations)
    for (identifier, description) in locations {
      let key = LocationKey(stringValue: identifier)
      if let description {
        try described.encode(description, forKey: key)
      } else {
        try described.encodeNil(forKey: key)
      }
    }
  }

  private enum CodingKeys: String, CodingKey {
    case locations
  }

  // The service names locations with identifiers it chooses, so each one is a key read at run time
  // rather than a case of a fixed key type.
  private struct LocationKey: CodingKey {
    var intValue: Int? { nil }
    let stringValue: String

    init(stringValue: String) { self.stringValue = stringValue }

    init?(intValue: Int) { nil }
  }
}
