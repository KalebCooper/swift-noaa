/// One weather phenomenon a station reported, decoded from a METAR present weather group.
///
/// The service decodes groups such as `+RA` or `BR` into their parts and keeps the original group in
/// ``rawString``. A part the group does not carry is `nil`, and codes this package does not name
/// survive in their `rawValue`.
///
/// ```swift
/// for phenomenon in observation.presentWeather ?? [] {
///   print(phenomenon.rawString, phenomenon.intensity?.rawValue ?? "", phenomenon.weather.rawValue)
/// }
/// ```
public struct WeatherPhenomenon: Codable, Hashable, Sendable {
  /// Whether the phenomenon was near the station rather than at it, when the service says.
  public var inVicinity: Bool?

  /// How strong the phenomenon was, or `nil` for moderate intensity or none reported.
  public var intensity: WeatherPhenomenonIntensity?

  /// A descriptor that qualifies the phenomenon, such as ``WeatherPhenomenonModifier/freezing``.
  public var modifier: WeatherPhenomenonModifier?

  /// The METAR group the phenomenon was decoded from, such as `+RA`.
  public var rawString: String

  /// The kind of phenomenon, such as ``WeatherPhenomenonKind/rain``.
  public var weather: WeatherPhenomenonKind

  /// Creates a weather phenomenon.
  ///
  /// - Parameters:
  ///   - inVicinity: Whether the phenomenon was near the station rather than at it.
  ///   - intensity: How strong the phenomenon was.
  ///   - modifier: A descriptor that qualifies the phenomenon.
  ///   - rawString: The METAR group the phenomenon was decoded from.
  ///   - weather: The kind of phenomenon.
  public init(
    inVicinity: Bool? = nil,
    intensity: WeatherPhenomenonIntensity?,
    modifier: WeatherPhenomenonModifier?,
    rawString: String,
    weather: WeatherPhenomenonKind
  ) {
    self.inVicinity = inVicinity
    self.intensity = intensity
    self.modifier = modifier
    self.rawString = rawString
    self.weather = weather
  }
}
