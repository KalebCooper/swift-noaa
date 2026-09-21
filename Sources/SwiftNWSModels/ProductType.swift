/// One kind of text product the service issues, as a product catalog lists it.
///
/// A product type pairs the code the product routes take as a path segment with the name the
/// service displays for it. Both are required: a body missing either fails to decode rather than
/// substituting an empty value.
///
/// ```swift
/// let types = try await weather.productTypes(at: "EWX")
/// print(types.types.first?.productName ?? "")  // "Area Forecast Discussion"
/// ```
public struct ProductType: Codable, Hashable, Sendable {
  /// The code the product routes take as a path segment, such as `AFD`.
  public var productCode: ProductCode

  /// The name the service displays for the code, such as `Area Forecast Discussion`.
  public var productName: String

  /// Creates a product type.
  ///
  /// - Parameters:
  ///   - productCode: The code the product routes take as a path segment.
  ///   - productName: The name the service displays for the code.
  public init(productCode: ProductCode, productName: String) {
    self.productCode = productCode
    self.productName = productName
  }
}
