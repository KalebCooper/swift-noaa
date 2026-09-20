extension Endpoint where Response == WeatherGlossary {
  /// Retrieves the glossary of weather terms the service publishes, `/glossary`.
  ///
  /// The service offers this resource only as JSON-LD, so the endpoint asks for
  /// ``MediaType/jsonLD``. The endpoint carries no query items: the service documents no page size
  /// or cursor for the glossary and answers the whole list in one body.
  ///
  /// ```swift
  /// Endpoint.glossary.path  // "/glossary"
  /// ```
  public static var glossary: Self {
    builtIn(accept: .jsonLD, path: "/glossary")
  }
}
