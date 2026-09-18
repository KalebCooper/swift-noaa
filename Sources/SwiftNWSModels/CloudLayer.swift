/// One layer of cloud a station reported, with how much of the sky it covers and the height of its
/// base.
///
/// The service sends layers in the order the station reported them. A clear sky can arrive as a
/// single ``CloudLayerAmount/clear`` layer whose base value is `nil`, or as no layer at all.
///
/// ```swift
/// for layer in observation.cloudLayers ?? [] {
///   print(layer.amount.rawValue, layer.base.value ?? .nan, layer.base.unitCode)
/// }
/// ```
public struct CloudLayer: Codable, Hashable, Sendable {
  /// How much of the sky the layer covers, such as ``CloudLayerAmount/broken``.
  public var amount: CloudLayerAmount

  /// The height of the layer's base, whose value is `nil` when the station reports none.
  public var base: QuantitativeValue

  /// Creates a cloud layer.
  ///
  /// - Parameters:
  ///   - amount: How much of the sky the layer covers.
  ///   - base: The height of the layer's base.
  public init(amount: CloudLayerAmount, base: QuantitativeValue) {
    self.amount = amount
    self.base = base
  }
}
