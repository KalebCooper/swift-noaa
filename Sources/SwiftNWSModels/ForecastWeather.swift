/// One expected weather phenomenon in raw forecast grid data.
///
/// Each interval of the grid's weather layer lists one or more of these, because several phenomena
/// can be expected at once. A period with no expected weather is one value whose coverage,
/// phenomenon, and intensity are all `nil`; it is kept, not filtered out.
///
/// ```swift
/// for entry in grid.weather?.values ?? [] {
///   for weather in entry.value where weather.phenomenon != nil {
///     print(weather.coverage?.rawValue ?? "", weather.phenomenon?.rawValue ?? "")
///   }
/// }
/// ```
public struct ForecastWeather: Codable, Hashable, Sendable {
  /// Additional attributes of the weather, such as heavy rain or gusty wind, in service order.
  public var attributes: [ForecastWeatherAttribute]

  /// How much of the area, or how likely, the weather is, or `nil` when the service sends none.
  public var coverage: ForecastWeatherCoverage?

  /// How intense the weather is, or `nil` when the service sends none.
  public var intensity: ForecastWeatherIntensity?

  /// The weather phenomenon, or `nil` when the service sends none. The service names it `weather`.
  public var phenomenon: ForecastWeatherPhenomenon?

  /// The expected visibility. The service often sends a unit with a `nil` value.
  public var visibility: QuantitativeValue

  /// Creates an expected weather phenomenon.
  ///
  /// - Parameters:
  ///   - attributes: Additional attributes, in service order.
  ///   - coverage: How much of the area, or how likely, the weather is.
  ///   - intensity: How intense the weather is.
  ///   - phenomenon: The weather phenomenon.
  ///   - visibility: The expected visibility.
  public init(
    attributes: [ForecastWeatherAttribute] = [],
    coverage: ForecastWeatherCoverage? = nil,
    intensity: ForecastWeatherIntensity? = nil,
    phenomenon: ForecastWeatherPhenomenon? = nil,
    visibility: QuantitativeValue
  ) {
    self.attributes = attributes
    self.coverage = coverage
    self.intensity = intensity
    self.phenomenon = phenomenon
    self.visibility = visibility
  }

  /// Decodes an expected weather phenomenon.
  /// - Parameter decoder: The decoder to read.
  /// - Throws: `DecodingError` when `attributes` or `visibility` is missing or malformed.
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.init(
      attributes: try container.decode([ForecastWeatherAttribute].self, forKey: .attributes),
      coverage: try container.decodeIfPresent(ForecastWeatherCoverage.self, forKey: .coverage),
      intensity: try container.decodeIfPresent(ForecastWeatherIntensity.self, forKey: .intensity),
      phenomenon: try container.decodeIfPresent(
        ForecastWeatherPhenomenon.self, forKey: .phenomenon),
      visibility: try container.decode(QuantitativeValue.self, forKey: .visibility))
  }

  /// Encodes the service's shape, writing `null` for a missing code.
  /// - Parameter encoder: The encoder to write.
  /// - Throws: Any error from the encoder.
  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(attributes, forKey: .attributes)
    try container.encode(coverage, forKey: .coverage)
    try container.encode(intensity, forKey: .intensity)
    try container.encode(phenomenon, forKey: .phenomenon)
    try container.encode(visibility, forKey: .visibility)
  }

  private enum CodingKeys: String, CodingKey {
    case attributes
    case coverage
    case intensity
    case phenomenon = "weather"
    case visibility
  }
}
