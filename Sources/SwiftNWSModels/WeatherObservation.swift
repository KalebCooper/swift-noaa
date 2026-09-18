#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// Conditions one station measured at one time, from `/stations/{stationId}/observations/latest`
/// or one feature of `/stations/{stationId}/observations`.
///
/// Every measurement is optional twice over: a field the station does not report is absent, and a
/// field it reports without a reading carries a ``QuantitativeValue`` whose `value` is `nil`. The
/// service omits some fields for some reports, such as a precipitation period the report does not
/// cover. Readings keep the unit the service sent, unconverted, and codes this package does not name
/// survive in their `rawValue`.
///
/// ```swift
/// let feature = try JSONDecoder().decode(Feature<WeatherObservation>.self, from: body)
/// let observation = feature.properties
/// print(observation.textDescription ?? "", observation.temperature?.value ?? .nan)
/// for phenomenon in observation.presentWeather ?? [] {
///   print(phenomenon.rawString)  // "+RA"
/// }
/// ```
///
/// The timestamp is read and written as an ISO 8601 string by the model itself, so it decodes the
/// same under any `JSONDecoder` date strategy.
public struct WeatherObservation: Codable, Hashable, Sendable {
  /// The air pressure at the station.
  public var barometricPressure: QuantitativeValue?

  /// The cloud layers the station reported, in the order it reported them, or `nil` when the service
  /// sends none. An empty array means the station reported no layer.
  public var cloudLayers: [CloudLayer]?

  /// The dew point.
  public var dewpoint: QuantitativeValue?

  /// The station's elevation.
  public var elevation: QuantitativeValue?

  /// The heat index, when conditions call for one.
  public var heatIndex: QuantitativeValue?

  /// A link to an icon for the conditions, which the service has deprecated and may send as `null`.
  public var icon: URL?

  /// The highest temperature in the 24 hours before the observation.
  public var maxTemperatureLast24Hours: QuantitativeValue?

  /// The lowest temperature in the 24 hours before the observation.
  public var minTemperatureLast24Hours: QuantitativeValue?

  /// The precipitation in the 3 hours before the observation.
  public var precipitationLast3Hours: QuantitativeValue?

  /// The precipitation in the 6 hours before the observation.
  public var precipitationLast6Hours: QuantitativeValue?

  /// The precipitation in the hour before the observation.
  public var precipitationLastHour: QuantitativeValue?

  /// The weather phenomena the station reported, such as heavy rain and mist, in the order it reported
  /// them. An empty array means the station reported none.
  public var presentWeather: [WeatherPhenomenon]?

  /// The METAR report the observation was decoded from, which the service may send empty.
  public var rawMessage: String?

  /// The relative humidity, in percent.
  public var relativeHumidity: QuantitativeValue?

  /// The air pressure reduced to sea level.
  public var seaLevelPressure: QuantitativeValue?

  /// A link to the station that made the observation.
  public var station: URL?

  /// The identifier of the station that made the observation, such as `KATT`.
  public var stationId: String

  /// The name of the station that made the observation.
  public var stationName: String?

  /// The air temperature.
  public var temperature: QuantitativeValue?

  /// A short description of the conditions, such as `Clear`, which the service may send empty.
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
  ///   - cloudLayers: The cloud layers the station reported.
  ///   - dewpoint: The dew point.
  ///   - elevation: The station's elevation.
  ///   - heatIndex: The heat index.
  ///   - icon: A link to an icon for the conditions.
  ///   - maxTemperatureLast24Hours: The highest temperature in the previous 24 hours.
  ///   - minTemperatureLast24Hours: The lowest temperature in the previous 24 hours.
  ///   - precipitationLast3Hours: The precipitation in the previous 3 hours.
  ///   - precipitationLast6Hours: The precipitation in the previous 6 hours.
  ///   - precipitationLastHour: The precipitation in the previous hour.
  ///   - presentWeather: The weather phenomena the station reported.
  ///   - rawMessage: The METAR report the observation was decoded from.
  ///   - relativeHumidity: The relative humidity.
  ///   - seaLevelPressure: The air pressure reduced to sea level.
  ///   - station: A link to the station.
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
    cloudLayers: [CloudLayer]? = nil,
    dewpoint: QuantitativeValue? = nil,
    elevation: QuantitativeValue? = nil,
    heatIndex: QuantitativeValue? = nil,
    icon: URL? = nil,
    maxTemperatureLast24Hours: QuantitativeValue? = nil,
    minTemperatureLast24Hours: QuantitativeValue? = nil,
    precipitationLast3Hours: QuantitativeValue? = nil,
    precipitationLast6Hours: QuantitativeValue? = nil,
    precipitationLastHour: QuantitativeValue? = nil,
    presentWeather: [WeatherPhenomenon]? = nil,
    rawMessage: String? = nil,
    relativeHumidity: QuantitativeValue? = nil,
    seaLevelPressure: QuantitativeValue? = nil,
    station: URL? = nil,
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
    self.cloudLayers = cloudLayers
    self.dewpoint = dewpoint
    self.elevation = elevation
    self.heatIndex = heatIndex
    self.icon = icon
    self.maxTemperatureLast24Hours = maxTemperatureLast24Hours
    self.minTemperatureLast24Hours = minTemperatureLast24Hours
    self.precipitationLast3Hours = precipitationLast3Hours
    self.precipitationLast6Hours = precipitationLast6Hours
    self.precipitationLastHour = precipitationLastHour
    self.presentWeather = presentWeather
    self.rawMessage = rawMessage
    self.relativeHumidity = relativeHumidity
    self.seaLevelPressure = seaLevelPressure
    self.station = station
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
    case cloudLayers
    case dewpoint
    case elevation
    case heatIndex
    case icon
    case maxTemperatureLast24Hours
    case minTemperatureLast24Hours
    case precipitationLast3Hours
    case precipitationLast6Hours
    case precipitationLastHour
    case presentWeather
    case rawMessage
    case relativeHumidity
    case seaLevelPressure
    case station
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
      cloudLayers: try container.decodeIfPresent([CloudLayer].self, forKey: .cloudLayers),
      dewpoint: try container.decodeIfPresent(QuantitativeValue.self, forKey: .dewpoint),
      elevation: try container.decodeIfPresent(QuantitativeValue.self, forKey: .elevation),
      heatIndex: try container.decodeIfPresent(QuantitativeValue.self, forKey: .heatIndex),
      icon: try container.decodeIfPresent(URL.self, forKey: .icon),
      maxTemperatureLast24Hours: try container.decodeIfPresent(
        QuantitativeValue.self, forKey: .maxTemperatureLast24Hours),
      minTemperatureLast24Hours: try container.decodeIfPresent(
        QuantitativeValue.self, forKey: .minTemperatureLast24Hours),
      precipitationLast3Hours: try container.decodeIfPresent(
        QuantitativeValue.self, forKey: .precipitationLast3Hours),
      precipitationLast6Hours: try container.decodeIfPresent(
        QuantitativeValue.self, forKey: .precipitationLast6Hours),
      precipitationLastHour: try container.decodeIfPresent(
        QuantitativeValue.self, forKey: .precipitationLastHour),
      presentWeather: try container.decodeIfPresent(
        [WeatherPhenomenon].self, forKey: .presentWeather),
      rawMessage: try container.decodeIfPresent(String.self, forKey: .rawMessage),
      relativeHumidity: try container.decodeIfPresent(
        QuantitativeValue.self, forKey: .relativeHumidity),
      seaLevelPressure: try container.decodeIfPresent(
        QuantitativeValue.self, forKey: .seaLevelPressure),
      station: try container.decodeIfPresent(URL.self, forKey: .station),
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
    try container.encodeIfPresent(cloudLayers, forKey: .cloudLayers)
    try container.encodeIfPresent(dewpoint, forKey: .dewpoint)
    try container.encodeIfPresent(elevation, forKey: .elevation)
    try container.encodeIfPresent(heatIndex, forKey: .heatIndex)
    try container.encodeIfPresent(icon, forKey: .icon)
    try container.encodeIfPresent(maxTemperatureLast24Hours, forKey: .maxTemperatureLast24Hours)
    try container.encodeIfPresent(minTemperatureLast24Hours, forKey: .minTemperatureLast24Hours)
    try container.encodeIfPresent(precipitationLast3Hours, forKey: .precipitationLast3Hours)
    try container.encodeIfPresent(precipitationLast6Hours, forKey: .precipitationLast6Hours)
    try container.encodeIfPresent(precipitationLastHour, forKey: .precipitationLastHour)
    try container.encodeIfPresent(presentWeather, forKey: .presentWeather)
    try container.encodeIfPresent(rawMessage, forKey: .rawMessage)
    try container.encodeIfPresent(relativeHumidity, forKey: .relativeHumidity)
    try container.encodeIfPresent(seaLevelPressure, forKey: .seaLevelPressure)
    try container.encodeIfPresent(station, forKey: .station)
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
