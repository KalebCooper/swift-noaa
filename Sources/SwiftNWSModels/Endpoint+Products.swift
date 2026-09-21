extension Endpoint where Response == ProductLocations {
  /// Lists every location the service issues text products for, `/products/locations`.
  ///
  /// The service offers this resource only as JSON-LD, so the endpoint asks for
  /// ``MediaType/jsonLD`` and sends no feature flags. The route documents no page size or cursor,
  /// so the endpoint carries no query items and the service answers the whole catalog in one body.
  ///
  /// ```swift
  /// Endpoint.productLocations.path  // "/products/locations"
  /// ```
  public static var productLocations: Self {
    builtIn(accept: .jsonLD, path: "/products/locations")
  }

  /// Lists the locations one kind of product is issued for,
  /// `/products/types/{typeId}/locations`.
  ///
  /// The service offers this resource only as JSON-LD, so the endpoint asks for
  /// ``MediaType/jsonLD`` and sends no feature flags or query items. The code is encoded as one
  /// path segment and is not upper-cased or otherwise normalized.
  ///
  /// ```swift
  /// Endpoint.productLocations(for: .areaForecastDiscussion)?.path
  /// // "/products/types/AFD/locations"
  /// ```
  ///
  /// - Parameter type: The product's code, such as ``ProductCode/areaForecastDiscussion``,
  ///   encoded as one path segment.
  /// - Returns: The endpoint, or nil for an empty code or an invalid encoded path.
  public static func productLocations(for type: ProductCode) -> Self? {
    guard let code = productSegment(type.rawValue) else { return nil }
    return Self(accept: .jsonLD, path: "/products/types/" + code + "/locations")
  }

  /// Lists the locations one kind of product is issued for using a consumer-defined product code
  /// enum.
  /// - Parameter type: A String-backed product code.
  /// - Returns: The endpoint, or nil for an empty code or an invalid encoded path.
  public static func productLocations<Code>(for type: Code) -> Self?
  where Code: RawRepresentable, Code.RawValue == String {
    productLocations(for: ProductCode(type))
  }
}

extension Endpoint where Response == ProductTypes {
  /// Lists every kind of text product the service issues, `/products/types`.
  ///
  /// The service offers this resource only as JSON-LD, so the endpoint asks for
  /// ``MediaType/jsonLD`` and sends no feature flags. The route documents no page size or cursor,
  /// so the endpoint carries no query items and the service answers the whole catalog in one body.
  ///
  /// ```swift
  /// Endpoint.productTypes.path  // "/products/types"
  /// ```
  public static var productTypes: Self {
    builtIn(accept: .jsonLD, path: "/products/types")
  }

  /// Lists the kinds of product issued for one location,
  /// `/products/locations/{locationId}/types`.
  ///
  /// The service offers this resource only as JSON-LD, so the endpoint asks for
  /// ``MediaType/jsonLD`` and sends no feature flags or query items. The identifier is encoded as
  /// one path segment and is not upper-cased or otherwise normalized.
  ///
  /// ```swift
  /// Endpoint.productTypes(at: "EWX")?.path  // "/products/locations/EWX/types"
  /// ```
  ///
  /// - Parameter location: The location's identifier, such as `EWX`, encoded as one path segment.
  /// - Returns: The endpoint, or nil for an empty identifier or an invalid encoded path.
  public static func productTypes(at location: String) -> Self? {
    guard let location = productSegment(location) else { return nil }
    return Self(accept: .jsonLD, path: "/products/locations/" + location + "/types")
  }
}

extension Endpoint where Response == TextProduct {
  /// The latest product of one kind issued for one location,
  /// `/products/types/{typeId}/locations/{locationId}/latest`.
  ///
  /// The service selects the product, so this is one request rather than a list followed by a
  /// detail lookup. The service offers this resource only as JSON-LD, so the endpoint asks for
  /// ``MediaType/jsonLD`` and sends no feature flags or query items. The code and the identifier
  /// are each encoded as one path segment and are not upper-cased or otherwise normalized.
  ///
  /// ```swift
  /// Endpoint.latestProduct(at: "EWX", ofType: .areaForecastDiscussion)?.path
  /// // "/products/types/AFD/locations/EWX/latest"
  /// ```
  ///
  /// - Parameters:
  ///   - location: The product location's identifier, such as `EWX`.
  ///   - type: The product's code, such as ``ProductCode/areaForecastDiscussion``.
  /// - Returns: The endpoint, or nil for an empty code or identifier, or an invalid encoded path.
  public static func latestProduct(at location: String, ofType type: ProductCode) -> Self? {
    guard let code = productSegment(type.rawValue), let location = productSegment(location) else {
      return nil
    }
    return Self(
      accept: .jsonLD, path: "/products/types/" + code + "/locations/" + location + "/latest")
  }

  /// The latest product of one kind issued for one location using a consumer-defined product code
  /// enum.
  /// - Parameters:
  ///   - location: The product location's identifier.
  ///   - type: A String-backed product code.
  /// - Returns: The endpoint, or nil for an empty code or identifier, or an invalid encoded path.
  public static func latestProduct<Code>(at location: String, ofType type: Code) -> Self?
  where Code: RawRepresentable, Code.RawValue == String {
    latestProduct(at: location, ofType: ProductCode(type))
  }

  /// One text product by identifier, `/products/{productId}`.
  ///
  /// The service offers this resource only as JSON-LD, so the endpoint asks for
  /// ``MediaType/jsonLD`` and sends no feature flags or query items. The identifier is encoded as
  /// one path segment and is not upper-cased or otherwise normalized.
  ///
  /// ```swift
  /// Endpoint.product(identifier: "a6addd61-6620-4718-9d53-effd7d8c2560")?.path
  /// // "/products/a6addd61-6620-4718-9d53-effd7d8c2560"
  /// ```
  ///
  /// - Parameter identifier: The product's identifier, such as
  ///   `a6addd61-6620-4718-9d53-effd7d8c2560`, encoded as one path segment.
  /// - Returns: The endpoint, or nil for an empty identifier or an invalid encoded path.
  public static func product(identifier: String) -> Self? {
    guard let identifier = productSegment(identifier) else { return nil }
    return Self(accept: .jsonLD, path: "/products/" + identifier)
  }
}

extension Endpoint where Response == TextProducts {
  /// The text products matching a validated query, `/products`.
  ///
  /// The service offers this resource only as JSON-LD, so the endpoint asks for
  /// ``MediaType/jsonLD`` and sends no feature flags. The query supplies every parameter the route
  /// accepts; the route declares no cursor, so nothing continues the list.
  ///
  /// ```swift
  /// let query = try ProductQuery(limit: 2, locations: ["EWX"], types: [.areaForecastDiscussion])
  /// Endpoint.products(matching: query).path  // "/products?limit=2&location=EWX&type=AFD"
  /// ```
  ///
  /// - Parameter query: The validated filters, window, and page size.
  /// - Returns: The endpoint for that query.
  public static func products(matching query: ProductQuery) -> Self {
    builtIn(accept: .jsonLD, path: "/products" + query.query)
  }

  /// The text products of one kind issued for one location,
  /// `/products/types/{typeId}/locations/{locationId}`.
  ///
  /// The service offers this resource only as JSON-LD, so the endpoint asks for
  /// ``MediaType/jsonLD`` and sends no feature flags or query items. The code and the identifier
  /// are each encoded as one path segment and are not upper-cased or otherwise normalized.
  ///
  /// ```swift
  /// Endpoint.products(at: "EWX", ofType: .areaForecastDiscussion)?.path
  /// // "/products/types/AFD/locations/EWX"
  /// ```
  ///
  /// - Parameters:
  ///   - location: The product location's identifier, such as `EWX`.
  ///   - type: The product's code, such as ``ProductCode/areaForecastDiscussion``.
  /// - Returns: The endpoint, or nil for an empty code or identifier, or an invalid encoded path.
  public static func products(at location: String, ofType type: ProductCode) -> Self? {
    guard let code = productSegment(type.rawValue), let location = productSegment(location) else {
      return nil
    }
    return Self(accept: .jsonLD, path: "/products/types/" + code + "/locations/" + location)
  }

  /// The text products of one kind issued for one location using a consumer-defined product code
  /// enum.
  /// - Parameters:
  ///   - location: The product location's identifier.
  ///   - type: A String-backed product code.
  /// - Returns: The endpoint, or nil for an empty code or identifier, or an invalid encoded path.
  public static func products<Code>(at location: String, ofType type: Code) -> Self?
  where Code: RawRepresentable, Code.RawValue == String {
    products(at: location, ofType: ProductCode(type))
  }

  /// The text products of one kind, `/products/types/{typeId}`.
  ///
  /// The service offers this resource only as JSON-LD, so the endpoint asks for
  /// ``MediaType/jsonLD`` and sends no feature flags or query items. The code is encoded as one
  /// path segment and is not upper-cased or otherwise normalized.
  ///
  /// ```swift
  /// Endpoint.products(ofType: .areaForecastDiscussion)?.path  // "/products/types/AFD"
  /// ```
  ///
  /// - Parameter type: The product's code, such as ``ProductCode/areaForecastDiscussion``.
  /// - Returns: The endpoint, or nil for an empty code or an invalid encoded path.
  public static func products(ofType type: ProductCode) -> Self? {
    guard let code = productSegment(type.rawValue) else { return nil }
    return Self(accept: .jsonLD, path: "/products/types/" + code)
  }

  /// The text products of one kind using a consumer-defined product code enum.
  /// - Parameter type: A String-backed product code.
  /// - Returns: The endpoint, or nil for an empty code or an invalid encoded path.
  public static func products<Code>(ofType type: Code) -> Self?
  where Code: RawRepresentable, Code.RawValue == String {
    products(ofType: ProductCode(type))
  }
}

extension Endpoint {
  // Every product route shares one validated segment, and the SDK reports an unusable product code
  // separately from an unusable location identifier.
  package static func productSegment(_ value: String) -> String? {
    guard !value.isEmpty else { return nil }
    let segment = encodedSegment(value)
    guard Self(path: "/products/" + segment) != nil else { return nil }
    return segment
  }
}
