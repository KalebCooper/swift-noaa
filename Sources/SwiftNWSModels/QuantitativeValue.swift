/// A measurement and the unit it is expressed in.
///
/// The API reports most numbers this way. The unit is a WMO unit code such as `wmoUnit:degC`, and
/// ``value`` is `nil` when the measurement is missing, which is common in observations.
///
/// ```swift
/// if let celsius = observation.temperature?.value {
///   print("\(celsius) \(observation.temperature?.unitCode ?? "")")
/// }
/// ```
public struct QuantitativeValue: Codable, Hashable, Sendable {
  /// The largest value in a range of measurements, when the API reports a range.
  public var maxValue: Double?

  /// The smallest value in a range of measurements, when the API reports a range.
  public var minValue: Double?

  /// The quality control flag the observation system assigned to the measurement, such as `V` for
  /// verified.
  public var qualityControl: String?

  /// The WMO unit code the measurement is expressed in, such as `wmoUnit:degC` or `wmoUnit:km_h-1`.
  public var unitCode: String

  /// The measurement, or `nil` when it is missing.
  public var value: Double?

  /// Creates a measurement.
  ///
  /// - Parameters:
  ///   - maxValue: The largest value in a range of measurements.
  ///   - minValue: The smallest value in a range of measurements.
  ///   - qualityControl: The quality control flag.
  ///   - unitCode: The WMO unit code, such as `wmoUnit:degC`.
  ///   - value: The measurement, or `nil` when it is missing.
  public init(
    maxValue: Double? = nil,
    minValue: Double? = nil,
    qualityControl: String? = nil,
    unitCode: String,
    value: Double?
  ) {
    self.maxValue = maxValue
    self.minValue = minValue
    self.qualityControl = qualityControl
    self.unitCode = unitCode
    self.value = value
  }
}
