/// An extensible code naming one kind of text product the service issues.
///
/// A code is the `typeId` segment of the product routes, such as `AFD` in
/// `/products/types/AFD/locations`. The service catalogs hundreds of codes and adds to them, so
/// named values cover only the few this package spells out; every other code the catalog lists is
/// usable through ``init(rawValue:)`` and remains available in ``rawValue``.
///
/// ```swift
/// let locations = try await weather.productLocations(for: .areaForecastDiscussion)
/// print(locations.locations["EWX"] ?? nil)  // "Austin/San Antonio, TX"
/// ```
public struct ProductCode: Codable, Hashable, RawRepresentable, Sendable {
  /// An office's area forecast discussion, `AFD`.
  public static let areaForecastDiscussion = Self(rawValue: "AFD")

  /// A public zone forecast, `ZFP`.
  public static let publicZoneForecast = Self(rawValue: "ZFP")

  /// A special weather statement, `SPS`.
  public static let specialWeatherStatement = Self(rawValue: "SPS")

  /// The service's exact code.
  public let rawValue: String

  /// Creates a code from a consumer-defined String-backed value.
  public init<Value>(_ value: Value) where Value: RawRepresentable, Value.RawValue == String {
    self.init(rawValue: value.rawValue)
  }

  /// Creates a code without restricting future service values.
  public init(rawValue: String) { self.rawValue = rawValue }

  /// Decodes the exact service code.
  public init(from decoder: any Decoder) throws {
    rawValue = try decoder.singleValueContainer().decode(String.self)
  }

  /// Encodes the exact service code.
  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(rawValue)
  }
}
