/// The kinds of text product a catalog lists, from `/products/types` and
/// `/products/locations/{locationId}/types`.
///
/// Types keep the order the service listed them in. A body without a `@graph` array, or with one
/// that is not an array of product types, fails to decode rather than producing an empty list.
///
/// The routes document no page size or cursor, so this package offers no product type pagination,
/// ordering policy, or filtering by code or name.
///
/// ```swift
/// let types = try await weather.productTypes()
/// print(types.types.count)  // 338
/// ```
public struct ProductTypes: Codable, Hashable, Sendable {
  /// The product types, in the order the service listed them.
  public var types: [ProductType]

  /// Creates a product type catalog.
  ///
  /// - Parameter types: The product types, in the order they should be kept.
  public init(types: [ProductType]) {
    self.types = types
  }

  private enum CodingKeys: String, CodingKey {
    case types = "@graph"
  }
}
