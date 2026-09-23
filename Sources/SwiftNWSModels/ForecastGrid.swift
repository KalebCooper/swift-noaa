#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// Raw forecast data for a 2.5 km grid cell, from `/gridpoints/{wfo}/{x},{y}`.
///
/// The grid is the data behind the text forecasts: every layer the forecast office publishes for
/// the cell, each as values over ISO 8601 intervals. Reach it by following a point's
/// ``WeatherPoint/forecastGridData`` link.
///
/// ```swift
/// let grid = try JSONDecoder().decode(Feature<ForecastGrid>.self, from: body).properties
/// for entry in grid[.temperature]?.values ?? [] {
///   print(entry.validTime.start, entry.value ?? .nan)
/// }
/// ```
///
/// Quantitative layers are keyed by ``ForecastGridLayerName`` in ``layers``, and the subscript reads
/// one by name. The weather and hazards layers have their own types. The grid keeps what the service
/// sends:
///
/// - A layer the service omits has no entry. A layer the service sends with no values is present
///   with an empty ``ForecastGridLayer/values``. The service says some layers are not present in
///   all areas.
/// - Values, intervals, and units are kept as sent, in service order, with `null` values as `nil`.
///   No unit is converted or inferred, and no sentinel value is interpreted.
/// - A quantitative layer whose name the package does not know is kept in ``layers`` under its own
///   name. Any other property the package does not know is kept in ``otherProperties``.
///
/// Decoding fails if a named layer, the weather layer, or the hazards layer changes shape, or if any
/// `validTime` is not an ISO 8601 start and duration. The JSON-LD keys `@context`, `@id`, `@type`,
/// and `geometry` are metadata, not layers, and are not decoded.
public struct ForecastGrid: Codable, Hashable, Sendable {
  /// The grid cell's elevation.
  public var elevation: QuantitativeValue

  /// The link to the forecast office responsible for the grid.
  public var forecastOffice: URL

  /// The identifier of the forecast office whose grid this is, such as `EWX`.
  public var gridId: String

  /// The grid cell's column.
  public var gridX: Int

  /// The grid cell's row.
  public var gridY: Int

  /// Watches, warnings, and advisories in effect, or `nil` when the service omits the layer.
  ///
  /// A present layer with no values means nothing is in effect.
  public var hazards: ForecastGridLayer<[ForecastHazard]>?

  /// Every quantitative layer the service sent, keyed by name.
  public var layers: [ForecastGridLayerName: ForecastGridLayer<Double?>]

  /// Properties that are neither a known field nor a quantitative layer, kept as the service sent
  /// them.
  public var otherProperties: [String: JSONValue]

  /// When the grid data was last updated.
  public var updateTime: Date

  /// The interval the grid covers.
  public var validTimes: ValidTimeInterval

  /// Expected weather phenomena, or `nil` when the service omits the layer.
  public var weather: ForecastGridLayer<[ForecastWeather]>?

  /// Creates a forecast grid.
  ///
  /// - Parameters:
  ///   - elevation: The grid cell's elevation.
  ///   - forecastOffice: The link to the forecast office.
  ///   - gridId: The forecast office's identifier.
  ///   - gridX: The grid cell's column.
  ///   - gridY: The grid cell's row.
  ///   - hazards: Watches, warnings, and advisories in effect.
  ///   - layers: The quantitative layers, keyed by name.
  ///   - otherProperties: Properties that are neither a known field nor a quantitative layer.
  ///   - updateTime: When the grid data was last updated.
  ///   - validTimes: The interval the grid covers.
  ///   - weather: Expected weather phenomena.
  public init(
    elevation: QuantitativeValue,
    forecastOffice: URL,
    gridId: String,
    gridX: Int,
    gridY: Int,
    hazards: ForecastGridLayer<[ForecastHazard]>? = nil,
    layers: [ForecastGridLayerName: ForecastGridLayer<Double?>] = [:],
    otherProperties: [String: JSONValue] = [:],
    updateTime: Date,
    validTimes: ValidTimeInterval,
    weather: ForecastGridLayer<[ForecastWeather]>? = nil
  ) {
    self.elevation = elevation
    self.forecastOffice = forecastOffice
    self.gridId = gridId
    self.gridX = gridX
    self.gridY = gridY
    self.hazards = hazards
    self.layers = layers
    self.otherProperties = otherProperties
    self.updateTime = updateTime
    self.validTimes = validTimes
    self.weather = weather
  }

  /// The quantitative layer with a name, or `nil` when the service did not send it.
  ///
  /// ```swift
  /// let temperature = grid[.temperature]
  /// ```
  ///
  /// - Parameter name: The layer's name.
  public subscript(name: ForecastGridLayerName) -> ForecastGridLayer<Double?>? {
    get { layers[name] }
    set { layers[name] = newValue }
  }

  /// Decodes a grid, keying every quantitative layer by its name.
  /// - Parameter decoder: The decoder to read.
  /// - Throws: `DecodingError` for a missing or malformed field, a named layer or the weather or
  ///   hazards layer with an unexpected shape, or a malformed `validTime`.
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: Key.self)
    var layers: [ForecastGridLayerName: ForecastGridLayer<Double?>] = [:]
    var otherProperties: [String: JSONValue] = [:]
    for key in container.allKeys
    where !Self.fields.contains(key.stringValue) && !Self.metadata.contains(key.stringValue) {
      let name = ForecastGridLayerName(rawValue: key.stringValue)
      if ForecastGridLayerName.known.contains(name) {
        layers[name] = try container.decode(ForecastGridLayer<Double?>.self, forKey: key)
      } else if let layer = try? container.decode(ForecastGridLayer<Double?>.self, forKey: key) {
        layers[name] = layer
      } else {
        otherProperties[key.stringValue] = try container.decode(JSONValue.self, forKey: key)
      }
    }
    self.init(
      elevation: try container.decode(QuantitativeValue.self, forKey: Key("elevation")),
      forecastOffice: try container.decode(URL.self, forKey: Key("forecastOffice")),
      gridId: try container.decode(String.self, forKey: Key("gridId")),
      gridX: try container.decode(Int.self, forKey: Key("gridX")),
      gridY: try container.decode(Int.self, forKey: Key("gridY")),
      hazards: try container.decodeIfPresent(
        ForecastGridLayer<[ForecastHazard]>.self, forKey: Key("hazards")),
      layers: layers,
      otherProperties: otherProperties,
      updateTime: try container.decodeISO8601(forKey: Key("updateTime")),
      validTimes: try container.decode(ValidTimeInterval.self, forKey: Key("validTimes")),
      weather: try container.decodeIfPresent(
        ForecastGridLayer<[ForecastWeather]>.self, forKey: Key("weather")))
  }

  /// Encodes the service's shape: the fields, each layer under its name, and every other property.
  ///
  /// `updateTime` is written as ISO 8601 with fractional seconds. A property in
  /// ``otherProperties`` that shares a name with a field or layer is not written.
  ///
  /// - Parameter encoder: The encoder to write.
  /// - Throws: Any error from the encoder.
  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: Key.self)
    for (name, value) in otherProperties
    where !Self.fields.contains(name) && layers[ForecastGridLayerName(rawValue: name)] == nil {
      try container.encode(value, forKey: Key(name))
    }
    for (name, layer) in layers where !Self.fields.contains(name.rawValue) {
      try container.encode(layer, forKey: Key(name.rawValue))
    }
    try container.encode(elevation, forKey: Key("elevation"))
    try container.encode(forecastOffice, forKey: Key("forecastOffice"))
    try container.encode(gridId, forKey: Key("gridId"))
    try container.encode(gridX, forKey: Key("gridX"))
    try container.encode(gridY, forKey: Key("gridY"))
    try container.encodeIfPresent(hazards, forKey: Key("hazards"))
    try container.encode(
      updateTime.formatted(Date.ISO8601FormatStyle(includingFractionalSeconds: true)),
      forKey: Key("updateTime"))
    try container.encode(validTimes, forKey: Key("validTimes"))
    try container.encodeIfPresent(weather, forKey: Key("weather"))
  }

  // Properties with their own stored property, and never treated as layers.
  private static let fields: Set<String> = [
    "elevation", "forecastOffice", "gridId", "gridX", "gridY", "hazards", "updateTime",
    "validTimes", "weather",
  ]

  // JSON-LD framing the service writes alongside the properties; not grid data.
  private static let metadata: Set<String> = ["@context", "@id", "@type", "geometry"]

  private struct Key: CodingKey {
    var intValue: Int? { nil }
    let stringValue: String

    init(_ stringValue: String) { self.stringValue = stringValue }

    init(stringValue: String) { self.stringValue = stringValue }

    init?(intValue: Int) { nil }
  }
}
