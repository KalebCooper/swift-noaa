/// One layer of raw forecast grid data: its unit and its values over time.
///
/// Values keep the service's order and intervals. They are never sorted, merged, resampled, or
/// converted. A layer present with no values stays distinct from an absent layer: see
/// ``ForecastGrid``.
///
/// ```swift
/// if let temperature = grid[.temperature] {
///   for entry in temperature.values {
///     print(entry.validTime.start, entry.value ?? .nan, temperature.unitCode ?? "")
///   }
/// }
/// ```
///
/// Quantitative layers use `Double?` values. The weather and hazards layers use arrays of
/// ``ForecastWeather`` and ``ForecastHazard``. A consumer-defined `Decodable` value type works too.
public struct ForecastGridLayer<Value> {
  /// The WMO unit code the layer's values are expressed in, such as `wmoUnit:degC`, or `nil` when
  /// the service names no unit.
  ///
  /// The service omits the unit on some layers, such as `heatRisk` and every empty layer. No unit is
  /// inferred.
  public var unitCode: String?

  /// The layer's values in service order.
  public var values: [ForecastGridValue<Value>]

  /// Creates a layer.
  ///
  /// - Parameters:
  ///   - unitCode: The WMO unit code, or `nil` when the service names none.
  ///   - values: The values in service order.
  public init(unitCode: String? = nil, values: [ForecastGridValue<Value>]) {
    self.unitCode = unitCode
    self.values = values
  }
}

extension ForecastGridLayer: Decodable where Value: Decodable {
  /// Decodes a layer, reading its unit from `uom`.
  /// - Parameter decoder: The decoder to read.
  /// - Throws: `DecodingError` when `values` is missing or a value or interval is malformed.
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: ForecastGridLayerCodingKeys.self)
    self.init(
      unitCode: try container.decodeIfPresent(String.self, forKey: .unitCode),
      values: try container.decode([ForecastGridValue<Value>].self, forKey: .values))
  }
}

extension ForecastGridLayer: Encodable where Value: Encodable {
  /// Encodes a layer in the service's shape, writing its unit as `uom` when there is one.
  /// - Parameter encoder: The encoder to write.
  /// - Throws: Any error from the encoder.
  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: ForecastGridLayerCodingKeys.self)
    try container.encodeIfPresent(unitCode, forKey: .unitCode)
    try container.encode(values, forKey: .values)
  }
}

extension ForecastGridLayer: Equatable where Value: Equatable {}

extension ForecastGridLayer: Hashable where Value: Hashable {}

extension ForecastGridLayer: Sendable where Value: Sendable {}

private enum ForecastGridLayerCodingKeys: String, CodingKey {
  case unitCode = "uom"
  case values
}

/// One value of a forecast grid layer and the interval it applies to.
///
/// ```swift
/// let entry = grid[.temperature]?.values.first
/// print(entry?.validTime.rawValue)  // "2026-09-17T17:00:00+00:00/PT1H"
/// ```
///
/// Intervals keep the service's own lengths: one value can span an hour or several days. A
/// quantitative value is `nil` when the service sends `null` for the interval.
public struct ForecastGridValue<Value> {
  /// The interval the value applies to.
  public var validTime: ValidTimeInterval

  /// The value, exactly as the service sent it.
  public var value: Value

  /// Creates a grid value.
  ///
  /// - Parameters:
  ///   - validTime: The interval the value applies to.
  ///   - value: The value.
  public init(validTime: ValidTimeInterval, value: Value) {
    self.validTime = validTime
    self.value = value
  }
}

extension ForecastGridValue: Decodable where Value: Decodable {
  /// Decodes a value and its interval. Both keys must be present; a `null` optional value decodes
  /// as `nil`.
  /// - Parameter decoder: The decoder to read.
  /// - Throws: `DecodingError` for a missing key, a malformed value, or a `validTime` that is not an
  ///   ISO 8601 start and duration.
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: ForecastGridValueCodingKeys.self)
    self.init(
      validTime: try container.decode(ValidTimeInterval.self, forKey: .validTime),
      value: try container.decode(Value.self, forKey: .value))
  }
}

extension ForecastGridValue: Encodable where Value: Encodable {
  /// Encodes the value and its interval's exact text, writing a `nil` optional value as `null`.
  /// - Parameter encoder: The encoder to write.
  /// - Throws: Any error from the encoder.
  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: ForecastGridValueCodingKeys.self)
    try container.encode(validTime, forKey: .validTime)
    try container.encode(value, forKey: .value)
  }
}

extension ForecastGridValue: Equatable where Value: Equatable {}

extension ForecastGridValue: Hashable where Value: Hashable {}

extension ForecastGridValue: Sendable where Value: Sendable {}

extension ForecastGridValue where Value == Double? {
  /// Pairs the value with its layer's unit as a quantitative value.
  ///
  /// Use it to reach the SDK's measurement conversion for a grid value. No conversion happens here.
  ///
  /// ```swift
  /// if let layer = grid[.temperature], let entry = layer.values.first {
  ///   let quantity = entry.quantity(unitCode: layer.unitCode)
  /// }
  /// ```
  ///
  /// - Parameter unitCode: The layer's ``ForecastGridLayer/unitCode``.
  /// - Returns: The value and unit, or `nil` when the layer names no unit. A `nil` value with a unit
  ///   returns a quantity whose value is `nil`.
  public func quantity(unitCode: String?) -> QuantitativeValue? {
    unitCode.map { QuantitativeValue(unitCode: $0, value: value) }
  }
}

private enum ForecastGridValueCodingKeys: String, CodingKey {
  case validTime
  case value
}
