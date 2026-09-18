/// The name of a quantitative layer in raw forecast grid data, such as `temperature`.
///
/// Named values cover every quantitative layer the service's schema lists. The service says some
/// layers are not present in all areas, and it can add layers without notice, so the name is open:
/// ``ForecastGrid`` keys every quantitative layer it receives by its name, and a name the package does
/// not know yet works through ``init(rawValue:)``.
///
/// ```swift
/// let temperatures = grid[.temperature]?.values ?? []
/// let newer = grid[ForecastGridLayerName(rawValue: "newLayer")]
/// ```
///
/// The `weather` and `hazards` layers have their own shapes and are ``ForecastGrid/weather`` and
/// ``ForecastGrid/hazards`` rather than names here.
public struct ForecastGridLayerName: Codable, CodingKeyRepresentable, Hashable, RawRepresentable,
  Sendable
{
  /// The apparent temperature, combining heat index and wind chill.
  public static let apparentTemperature = Self(rawValue: "apparentTemperature")

  /// The atmospheric dispersion index, used in smoke management.
  public static let atmosphericDispersionIndex = Self(rawValue: "atmosphericDispersionIndex")

  /// The height of the cloud ceiling.
  public static let ceilingHeight = Self(rawValue: "ceilingHeight")

  /// The Davis stability index, used in fire weather.
  public static let davisStabilityIndex = Self(rawValue: "davisStabilityIndex")

  /// The dew point temperature.
  public static let dewpoint = Self(rawValue: "dewpoint")

  /// The dispersion index, used in smoke management.
  public static let dispersionIndex = Self(rawValue: "dispersionIndex")

  /// The grassland fire danger index.
  public static let grasslandFireDangerIndex = Self(rawValue: "grasslandFireDangerIndex")

  /// The Haines index of atmospheric potential for wildfire growth.
  public static let hainesIndex = Self(rawValue: "hainesIndex")

  /// The heat index.
  public static let heatIndex = Self(rawValue: "heatIndex")

  /// The HeatRisk category.
  public static let heatRisk = Self(rawValue: "heatRisk")

  /// The ice accumulation over each interval.
  public static let iceAccumulation = Self(rawValue: "iceAccumulation")

  /// The lightning activity level.
  public static let lightningActivityLevel = Self(rawValue: "lightningActivityLevel")

  /// The low visibility occurrence risk index, used in smoke management.
  public static let lowVisibilityOccurrenceRiskIndex = Self(
    rawValue: "lowVisibilityOccurrenceRiskIndex")

  /// The daytime maximum temperature.
  public static let maxTemperature = Self(rawValue: "maxTemperature")

  /// The overnight minimum temperature.
  public static let minTemperature = Self(rawValue: "minTemperature")

  /// The mixing height, used in smoke management.
  public static let mixingHeight = Self(rawValue: "mixingHeight")

  /// The probability of sustained winds of at least 15 mph.
  public static let potentialOf15mphWinds = Self(rawValue: "potentialOf15mphWinds")

  /// The probability of wind gusts of at least 20 mph.
  public static let potentialOf20mphWindGusts = Self(rawValue: "potentialOf20mphWindGusts")

  /// The probability of sustained winds of at least 25 mph.
  public static let potentialOf25mphWinds = Self(rawValue: "potentialOf25mphWinds")

  /// The probability of wind gusts of at least 30 mph.
  public static let potentialOf30mphWindGusts = Self(rawValue: "potentialOf30mphWindGusts")

  /// The probability of sustained winds of at least 35 mph.
  public static let potentialOf35mphWinds = Self(rawValue: "potentialOf35mphWinds")

  /// The probability of wind gusts of at least 40 mph.
  public static let potentialOf40mphWindGusts = Self(rawValue: "potentialOf40mphWindGusts")

  /// The probability of sustained winds of at least 45 mph.
  public static let potentialOf45mphWinds = Self(rawValue: "potentialOf45mphWinds")

  /// The probability of wind gusts of at least 50 mph.
  public static let potentialOf50mphWindGusts = Self(rawValue: "potentialOf50mphWindGusts")

  /// The probability of wind gusts of at least 60 mph.
  public static let potentialOf60mphWindGusts = Self(rawValue: "potentialOf60mphWindGusts")

  /// The atmospheric pressure.
  public static let pressure = Self(rawValue: "pressure")

  /// The direction the primary swell comes from.
  public static let primarySwellDirection = Self(rawValue: "primarySwellDirection")

  /// The height of the primary swell.
  public static let primarySwellHeight = Self(rawValue: "primarySwellHeight")

  /// The probability of hurricane-force winds.
  public static let probabilityOfHurricaneWinds = Self(rawValue: "probabilityOfHurricaneWinds")

  /// The probability of precipitation.
  public static let probabilityOfPrecipitation = Self(rawValue: "probabilityOfPrecipitation")

  /// The probability of thunder.
  public static let probabilityOfThunder = Self(rawValue: "probabilityOfThunder")

  /// The probability of tropical-storm-force winds.
  public static let probabilityOfTropicalStormWinds = Self(
    rawValue: "probabilityOfTropicalStormWinds")

  /// The liquid precipitation amount over each interval.
  public static let quantitativePrecipitation = Self(rawValue: "quantitativePrecipitation")

  /// The red flag threat index, used in fire weather.
  public static let redFlagThreatIndex = Self(rawValue: "redFlagThreatIndex")

  /// The relative humidity.
  public static let relativeHumidity = Self(rawValue: "relativeHumidity")

  /// The direction the secondary swell comes from.
  public static let secondarySwellDirection = Self(rawValue: "secondarySwellDirection")

  /// The height of the secondary swell.
  public static let secondarySwellHeight = Self(rawValue: "secondarySwellHeight")

  /// The fraction of the sky covered by cloud.
  public static let skyCover = Self(rawValue: "skyCover")

  /// The altitude above which precipitation falls as snow.
  public static let snowLevel = Self(rawValue: "snowLevel")

  /// The snowfall amount over each interval.
  public static let snowfallAmount = Self(rawValue: "snowfallAmount")

  /// The atmospheric stability class, used in smoke management.
  public static let stability = Self(rawValue: "stability")

  /// The air temperature.
  public static let temperature = Self(rawValue: "temperature")

  /// The direction of the transport wind, used in smoke management.
  public static let transportWindDirection = Self(rawValue: "transportWindDirection")

  /// The speed of the transport wind, used in smoke management.
  public static let transportWindSpeed = Self(rawValue: "transportWindSpeed")

  /// The wind direction twenty feet above the ground.
  public static let twentyFootWindDirection = Self(rawValue: "twentyFootWindDirection")

  /// The wind speed twenty feet above the ground.
  public static let twentyFootWindSpeed = Self(rawValue: "twentyFootWindSpeed")

  /// The horizontal visibility.
  public static let visibility = Self(rawValue: "visibility")

  /// The direction waves come from.
  public static let waveDirection = Self(rawValue: "waveDirection")

  /// The significant wave height.
  public static let waveHeight = Self(rawValue: "waveHeight")

  /// The wave period.
  public static let wavePeriod = Self(rawValue: "wavePeriod")

  /// The period of the secondary wave train.
  public static let wavePeriod2 = Self(rawValue: "wavePeriod2")

  /// The wet bulb globe temperature.
  public static let wetBulbGlobeTemperature = Self(rawValue: "wetBulbGlobeTemperature")

  /// The wind chill temperature.
  public static let windChill = Self(rawValue: "windChill")

  /// The direction the wind comes from.
  public static let windDirection = Self(rawValue: "windDirection")

  /// The wind gust speed.
  public static let windGust = Self(rawValue: "windGust")

  /// The sustained wind speed.
  public static let windSpeed = Self(rawValue: "windSpeed")

  /// The height of wind-driven waves.
  public static let windWaveHeight = Self(rawValue: "windWaveHeight")

  /// Every quantitative layer name the service's schema lists.
  static let known: Set<Self> = [
    .apparentTemperature,
    .atmosphericDispersionIndex,
    .ceilingHeight,
    .davisStabilityIndex,
    .dewpoint,
    .dispersionIndex,
    .grasslandFireDangerIndex,
    .hainesIndex,
    .heatIndex,
    .heatRisk,
    .iceAccumulation,
    .lightningActivityLevel,
    .lowVisibilityOccurrenceRiskIndex,
    .maxTemperature,
    .minTemperature,
    .mixingHeight,
    .potentialOf15mphWinds,
    .potentialOf20mphWindGusts,
    .potentialOf25mphWinds,
    .potentialOf30mphWindGusts,
    .potentialOf35mphWinds,
    .potentialOf40mphWindGusts,
    .potentialOf45mphWinds,
    .potentialOf50mphWindGusts,
    .potentialOf60mphWindGusts,
    .pressure,
    .primarySwellDirection,
    .primarySwellHeight,
    .probabilityOfHurricaneWinds,
    .probabilityOfPrecipitation,
    .probabilityOfThunder,
    .probabilityOfTropicalStormWinds,
    .quantitativePrecipitation,
    .redFlagThreatIndex,
    .relativeHumidity,
    .secondarySwellDirection,
    .secondarySwellHeight,
    .skyCover,
    .snowLevel,
    .snowfallAmount,
    .stability,
    .temperature,
    .transportWindDirection,
    .transportWindSpeed,
    .twentyFootWindDirection,
    .twentyFootWindSpeed,
    .visibility,
    .waveDirection,
    .waveHeight,
    .wavePeriod,
    .wavePeriod2,
    .wetBulbGlobeTemperature,
    .windChill,
    .windDirection,
    .windGust,
    .windSpeed,
    .windWaveHeight,
  ]

  /// The layer's exact name, used as its key when a name keys a JSON object.
  public var codingKey: any CodingKey { Key(stringValue: rawValue) }

  /// The layer's exact name as the service writes it.
  public let rawValue: String

  /// Creates a name from a consumer-defined String-backed value.
  /// - Parameter value: The value whose raw string to retain.
  public init<Value>(_ value: Value) where Value: RawRepresentable, Value.RawValue == String {
    self.init(rawValue: value.rawValue)
  }

  /// Creates a name from a JSON object key; every key is accepted as an exact layer name.
  /// - Parameter codingKey: The key whose string value is the layer's name.
  public init?<T: CodingKey>(codingKey: T) {
    self.init(rawValue: codingKey.stringValue)
  }

  /// Creates a name without restricting future service layers.
  /// - Parameter rawValue: The layer's exact name.
  public init(rawValue: String) { self.rawValue = rawValue }

  /// Decodes the exact layer name.
  /// - Parameter decoder: The decoder to read.
  /// - Throws: `DecodingError` for a non-string value.
  public init(from decoder: any Decoder) throws {
    rawValue = try decoder.singleValueContainer().decode(String.self)
  }

  /// Encodes the exact layer name.
  /// - Parameter encoder: The encoder to write.
  /// - Throws: Any error from the encoder.
  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(rawValue)
  }

  private struct Key: CodingKey {
    var intValue: Int? { nil }
    let stringValue: String

    init(stringValue: String) { self.stringValue = stringValue }

    init?(intValue: Int) { nil }
  }
}
