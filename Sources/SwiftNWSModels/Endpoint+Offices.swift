extension Endpoint where Response == OfficeBriefingResponse {
  /// Retrieves the metadata for an office's current weather briefing, `/offices/{officeId}/briefing`.
  ///
  /// The service offers this resource only as JSON-LD, so the endpoint asks for
  /// ``MediaType/jsonLD`` and sends no feature flags or query items. The identifier is encoded as
  /// one path segment and is not upper-cased or otherwise normalized. An office with no current
  /// briefing answers a `null` briefing rather than an error.
  ///
  /// ```swift
  /// Endpoint.officeBriefing(officeIdentifier: "LWX")?.path  // "/offices/LWX/briefing"
  /// ```
  ///
  /// - Parameter officeIdentifier: The office's identifier, such as `LWX`, encoded as one path
  ///   segment.
  /// - Returns: The endpoint, or nil for an empty identifier or an invalid encoded path.
  public static func officeBriefing(officeIdentifier: String) -> Self? {
    guard let office = officeSegment(officeIdentifier) else { return nil }
    return Self(accept: .jsonLD, path: "/offices/" + office + "/briefing")
  }
}

extension Endpoint where Response == OfficeHeadline {
  /// Retrieves one of an office's headlines, `/offices/{officeId}/headlines/{headlineId}`.
  ///
  /// The service offers this resource only as JSON-LD, so the endpoint asks for
  /// ``MediaType/jsonLD`` and sends no feature flags. Both identifiers are encoded as one path
  /// segment each.
  ///
  /// ```swift
  /// Endpoint.officeHeadline(
  ///   identifier: "ab45482ca5f57ff412eb1320721d5ac9", officeIdentifier: "EWX")?.path
  /// // "/offices/EWX/headlines/ab45482ca5f57ff412eb1320721d5ac9"
  /// ```
  ///
  /// - Parameters:
  ///   - identifier: The headline's identifier, encoded as one path segment.
  ///   - officeIdentifier: The office's identifier, such as `EWX`, encoded as one path segment.
  /// - Returns: The endpoint, or nil for an empty identifier or an invalid encoded path.
  public static func officeHeadline(identifier: String, officeIdentifier: String) -> Self? {
    guard let office = officeSegment(officeIdentifier), !identifier.isEmpty else { return nil }
    return Self(
      accept: .jsonLD,
      path: "/offices/" + office + "/headlines/" + encodedSegment(identifier))
  }
}

extension Endpoint where Response == OfficeHeadlines {
  /// Lists an office's editorial headlines, `/offices/{officeId}/headlines`.
  ///
  /// The service offers this resource only as JSON-LD, so the endpoint asks for
  /// ``MediaType/jsonLD`` and sends no feature flags. The route documents no page size or cursor,
  /// so the endpoint carries no query items and the service answers the whole list in one body.
  ///
  /// ```swift
  /// Endpoint.officeHeadlines(officeIdentifier: "EWX")?.path  // "/offices/EWX/headlines"
  /// ```
  ///
  /// - Parameter officeIdentifier: The office's identifier, such as `EWX`, encoded as one path
  ///   segment.
  /// - Returns: The endpoint, or nil for an empty identifier or an invalid encoded path.
  public static func officeHeadlines(officeIdentifier: String) -> Self? {
    guard let office = officeSegment(officeIdentifier) else { return nil }
    return Self(accept: .jsonLD, path: "/offices/" + office + "/headlines")
  }
}

extension Endpoint where Response == WeatherOffice {
  /// Retrieves one forecast office's metadata, `/offices/{officeId}`.
  ///
  /// The service offers this resource only as JSON-LD, so the endpoint asks for
  /// ``MediaType/jsonLD`` and sends no feature flags. The identifier is encoded as one path
  /// segment and is not upper-cased or otherwise normalized.
  ///
  /// ```swift
  /// Endpoint.office(identifier: "EWX")?.path  // "/offices/EWX"
  /// ```
  ///
  /// - Parameter identifier: The office's identifier, such as `EWX`, encoded as one path segment.
  /// - Returns: The endpoint, or nil for an empty identifier or an invalid encoded path.
  public static func office(identifier: String) -> Self? {
    guard let office = officeSegment(identifier) else { return nil }
    return Self(accept: .jsonLD, path: "/offices/" + office)
  }
}

extension Endpoint {
  // Every office route shares one validated office segment, and the SDK reports an unusable office
  // identifier separately from an unusable headline identifier.
  package static func officeSegment(_ identifier: String) -> String? {
    guard !identifier.isEmpty else { return nil }
    let segment = encodedSegment(identifier)
    guard Self(path: "/offices/" + segment) != nil else { return nil }
    return segment
  }
}
