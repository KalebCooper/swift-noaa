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
