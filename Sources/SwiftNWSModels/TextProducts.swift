/// The text products a query or a route lists, from `/products`, `/products/types/{typeId}`, and
/// `/products/types/{typeId}/locations/{locationId}`.
///
/// Products keep the order the service listed them in. A body without a `@graph` array, or with
/// one that is not an array of products, fails to decode rather than producing an empty list.
///
/// List entries carry no product text: the routes send a product's metadata only, and
/// ``TextProduct/productText`` is nil for every entry. Retrieve a bulletin's words with
/// ``TextProduct/id`` through the single-product route.
///
/// Of these three routes only `/products` accepts options, and a page size is one of them, set
/// through ``ProductQuery``; the other two take no query items and refuse one. No product route
/// declares a cursor, so nothing continues a list and this package pages no products.
///
/// ```swift
/// let products = try await weather.products(at: "EWX", ofType: .areaForecastDiscussion)
/// print(products.products.count)  // 33
/// ```
public struct TextProducts: Codable, Hashable, Sendable {
  /// The products, in the order the service listed them.
  public var products: [TextProduct]

  /// Creates a product list.
  ///
  /// - Parameter products: The products, in the order they should be kept.
  public init(products: [TextProduct]) {
    self.products = products
  }

  private enum CodingKeys: String, CodingKey {
    case products = "@graph"
  }
}
