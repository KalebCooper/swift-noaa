#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// Conditions one station measured at one time, from `/stations/{stationId}/observations/latest`.
///
/// Every measurement is optional twice over: a field the station does not report is absent, and a
/// field it reports without a reading carries a ``QuantitativeValue`` whose `value` is `nil`.
///
/// ```swift
/// let feature = try JSONDecoder().decode(Feature<WeatherObservation>.self, from: body)
/// let observation = feature.properties
/// print(observation.textDescription ?? "", observation.temperature?.value ?? .nan)
/// ```
///
/// The timestamp is read and written as an ISO 8601 string by the model itself, so it decodes the
/// same under any `JSONDecoder` date strategy.
public struct WeatherObservation: Codable, Hashable, Sendable {
  /// The air pressure at the station.
  public var barometricPressure: QuantitativeValue?

  /// The dew point.
  public var dewpoint: QuantitativeValue?

  /// The heat index, when conditions call for one.
  public var heatIndex: QuantitativeValue?

  /// The relative humidity, in percent.
  public var relativeHumidity: QuantitativeValue?

  /// The identifier of the station that made the observation, such as `KATT`.
  public var stationId: String

  /// The name of the station that made the observation.
  public var stationName: String?

  /// The air temperature.
  public var temperature: QuantitativeValue?

  /// A short description of the conditions, such as `Clear`.
  public var textDescription: String?

  /// When the observation was made.
  public var timestamp: Date

  /// The visibility.
  public var visibility: QuantitativeValue?

  /// The wind chill, when conditions call for one.
  public var windChill: QuantitativeValue?

  /// The direction the wind blows from, in degrees.
  public var windDirection: QuantitativeValue?

  /// The speed of the strongest gust.
  public var windGust: QuantitativeValue?

  /// The sustained wind speed.
  public var windSpeed: QuantitativeValue?

  /// Creates an observation.
  ///
  /// - Parameters:
  ///   - barometricPressure: The air pressure at the station.
  ///   - dewpoint: The dew point.
  ///   - heatIndex: The heat index.
  ///   - relativeHumidity: The relative humidity.
  ///   - stationId: The identifier of the station.
  ///   - stationName: The name of the station.
  ///   - temperature: The air temperature.
  ///   - textDescription: A short description of the conditions.
  ///   - timestamp: When the observation was made.
  ///   - visibility: The visibility.
  ///   - windChill: The wind chill.
  ///   - windDirection: The direction the wind blows from.
  ///   - windGust: The speed of the strongest gust.
  ///   - windSpeed: The sustained wind speed.
  public init(
    barometricPressure: QuantitativeValue? = nil,
    dewpoint: QuantitativeValue? = nil,
    heatIndex: QuantitativeValue? = nil,
    relativeHumidity: QuantitativeValue? = nil,
    stationId: String,
    stationName: String? = nil,
    temperature: QuantitativeValue? = nil,
    textDescription: String? = nil,
    timestamp: Date,
    visibility: QuantitativeValue? = nil,
    windChill: QuantitativeValue? = nil,
    windDirection: QuantitativeValue? = nil,
    windGust: QuantitativeValue? = nil,
    windSpeed: QuantitativeValue? = nil
  ) {
    self.barometricPressure = barometricPressure
    self.dewpoint = dewpoint
    self.heatIndex = heatIndex
    self.relativeHumidity = relativeHumidity
    self.stationId = stationId
    self.stationName = stationName
    self.temperature = temperature
    self.textDescription = textDescription
    self.timestamp = timestamp
    self.visibility = visibility
    self.windChill = windChill
    self.windDirection = windDirection
    self.windGust = windGust
    self.windSpeed = windSpeed
  }

  private enum CodingKeys: String, CodingKey {
    case barometricPressure
    case dewpoint
    case heatIndex
    case relativeHumidity
    case stationId
    case stationName
    case temperature
    case textDescription
    case timestamp
    case visibility
    case windChill
    case windDirection
    case windGust
    case windSpeed
  }

  /// Creates an observation by decoding it, reading the timestamp as an ISO 8601 string.
  ///
  /// - Parameter decoder: The decoder to read from.
  /// - Throws: `DecodingError` when a field is missing or malformed, including a timestamp that is
  ///   not ISO 8601.
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    let timestamp = try container.decode(String.self, forKey: .timestamp)
    guard let date = try? Date(timestamp, strategy: .iso8601) else {
      throw DecodingError.dataCorruptedError(
        forKey: .timestamp, in: container,
        debugDescription: "The timestamp \(timestamp) is not an ISO 8601 date.")
    }
    self.init(
      barometricPressure: try container.decodeIfPresent(
        QuantitativeValue.self, forKey: .barometricPressure),
      dewpoint: try container.decodeIfPresent(QuantitativeValue.self, forKey: .dewpoint),
      heatIndex: try container.decodeIfPresent(QuantitativeValue.self, forKey: .heatIndex),
      relativeHumidity: try container.decodeIfPresent(
        QuantitativeValue.self, forKey: .relativeHumidity),
      stationId: try container.decode(String.self, forKey: .stationId),
      stationName: try container.decodeIfPresent(String.self, forKey: .stationName),
      temperature: try container.decodeIfPresent(QuantitativeValue.self, forKey: .temperature),
      textDescription: try container.decodeIfPresent(String.self, forKey: .textDescription),
      timestamp: date,
      visibility: try container.decodeIfPresent(QuantitativeValue.self, forKey: .visibility),
      windChill: try container.decodeIfPresent(QuantitativeValue.self, forKey: .windChill),
      windDirection: try container.decodeIfPresent(QuantitativeValue.self, forKey: .windDirection),
      windGust: try container.decodeIfPresent(QuantitativeValue.self, forKey: .windGust),
      windSpeed: try container.decodeIfPresent(QuantitativeValue.self, forKey: .windSpeed)
    )
  }

  /// Encodes the observation, writing the timestamp as an ISO 8601 string.
  ///
  /// - Parameter encoder: The encoder to write to.
  /// - Throws: Whatever the encoder throws.
  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encodeIfPresent(barometricPressure, forKey: .barometricPressure)
    try container.encodeIfPresent(dewpoint, forKey: .dewpoint)
    try container.encodeIfPresent(heatIndex, forKey: .heatIndex)
    try container.encodeIfPresent(relativeHumidity, forKey: .relativeHumidity)
    try container.encode(stationId, forKey: .stationId)
    try container.encodeIfPresent(stationName, forKey: .stationName)
    try container.encodeIfPresent(temperature, forKey: .temperature)
    try container.encodeIfPresent(textDescription, forKey: .textDescription)
    try container.encode(timestamp.formatted(.iso8601), forKey: .timestamp)
    try container.encodeIfPresent(visibility, forKey: .visibility)
    try container.encodeIfPresent(windChill, forKey: .windChill)
    try container.encodeIfPresent(windDirection, forKey: .windDirection)
    try container.encodeIfPresent(windGust, forKey: .windGust)
    try container.encodeIfPresent(windSpeed, forKey: .windSpeed)
  }
}
