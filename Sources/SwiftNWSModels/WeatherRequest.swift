/// A reusable, typed description of a weather lookup.
///
/// Creating a request performs no I/O. Inspect ``resolution`` to execute it with your own
/// networking stack, or pass it to `NWSClient.value(for:)` in SwiftNWS.
///
/// Add application vocabulary through constrained extensions. Use ``init(endpoint:)`` to
/// describe additional single-HTTP operations with your own response models.
public struct WeatherRequest<Response>: Hashable, Sendable {
  /// The transport-independent work required to obtain a request's response.
  public enum Resolution: Hashable, Sendable {
    /// Send one endpoint and decode its body directly as `Response`.
    case endpoint(Endpoint<Response>)

    /// Fetch a point, follow its forecast link with the options, and return the properties.
    /// Only requests returning WeatherForecast carry this resolution.
    case forecast(location: WeatherCoordinate, options: ForecastOptions)

    /// Fetch a point, follow its hourly forecast link with the options, and return the properties.
    /// Only requests returning WeatherForecast carry this resolution.
    case hourlyForecast(location: WeatherCoordinate, options: ForecastOptions)

    /// Resolve the source and decode the latest observation's GeoJSON properties.
    ///
    /// Only requests whose response is ``WeatherObservation`` carry this resolution.
    /// For a coordinate, fetch its point, validate and follow its observation-stations link,
    /// and select the first station on the returned page. An empty list is a failure.
    /// Then fetch that station's latest observation. Do not fetch additional pages, filter
    /// by age, or try another station on failure.
    case latestObservation(ObservationSource)
  }

  /// The description an executor interprets, without any SDK or transport dependency.
  public let resolution: Resolution

  /// Creates a request for a single endpoint, including a consumer-defined endpoint.
  ///
  /// - Parameter endpoint: The endpoint whose body decodes directly as `Response`.
  public init(endpoint: Endpoint<Response>) {
    self.resolution = .endpoint(endpoint)
  }

  private init(resolution: Resolution) {
    self.resolution = resolution
  }
}

extension WeatherRequest where Response == WeatherForecast {
  /// Describes the twelve-hour forecast for a coordinate.
  /// - Parameters:
  ///   - location: The validated coordinate.
  ///   - options: Units and representation flags.
  /// - Returns: A reusable request that performs no I/O at construction.
  public static func forecast(for location: WeatherCoordinate, options: ForecastOptions = .init())
    -> Self
  {
    Self(resolution: .forecast(location: location, options: options))
  }

  /// Describes the hourly forecast for a coordinate.
  /// - Parameters:
  ///   - location: The validated coordinate.
  ///   - options: Units and representation flags.
  /// - Returns: A reusable request that performs no I/O at construction.
  public static func hourlyForecast(
    for location: WeatherCoordinate, options: ForecastOptions = .init()
  ) -> Self {
    Self(resolution: .hourlyForecast(location: location, options: options))
  }
}

extension WeatherRequest where Response == WeatherObservation {
  /// Describes the latest observation from an explicit station or a coordinate's station list.
  ///
  /// The result retains its station identifier and timestamp. No freshness policy or fallback
  /// is applied. ``ObservationSource/nearest(to:)`` uses the first station the service lists.
  ///
  /// - Parameter source: The station or coordinate to look up.
  /// - Returns: A request that performs no work until executed.
  public static func latestObservation(from source: ObservationSource) -> Self {
    Self(resolution: .latestObservation(source))
  }
}
