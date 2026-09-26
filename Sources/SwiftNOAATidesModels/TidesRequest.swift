/// A reusable description of a CO-OPS operation, with no I/O or transport dependency.
public struct TidesRequest<Response>: Hashable, Sendable {
  /// The portable work needed to obtain the response.
  public enum Resolution: Hashable, Sendable {
    /// Decode a single endpoint directly as Response.
    case endpoint(TidesEndpoint<Response>)
    /// Attach requested context to predicted high/low events.
    case highLowTides(HighLowTideQuery)
    /// Require exactly one matching station from its detail envelope.
    case station(CoastalStationIdentifier)
    /// Attach requested context to sampled tide predictions.
    case tidePredictions(TidePredictionQuery)
    /// Attach requested context to measured six-minute water levels.
    case waterLevels(WaterLevelQuery)
  }

  /// The work an executor interprets.
  public let resolution: Resolution

  private init(resolution: Resolution) { self.resolution = resolution }
}

extension TidesRequest where Response: Decodable {
  /// Creates a request for a consumer-defined or built-in single endpoint.
  /// - Parameter endpoint: The endpoint whose body decodes as Response.
  public init(endpoint: TidesEndpoint<Response>) {
    self.resolution = .endpoint(endpoint)
  }
}

extension TidesRequest where Response == CoastalDatums {
  /// Describes a station datum-table request without conversion.
  /// - Parameters:
  ///   - stationIdentifier: The validated station identifier.
  ///   - units: The requested metadata unit-system code.
  /// - Returns: A reusable single-endpoint request.
  /// - Throws: `TidesQueryError.invalidUnits` for an empty code or control characters.
  public static func datums(stationIdentifier: CoastalStationIdentifier, units: TidesUnits)
    throws(TidesQueryError) -> Self
  {
    Self(endpoint: try .datums(stationIdentifier: stationIdentifier, units: units))
  }
}

extension TidesRequest where Response == CoastalStation {
  /// Describes a detail lookup that requires one matching station.
  /// - Parameter identifier: A validated provider identifier.
  /// - Returns: A request that unwraps only a single matching station.
  public static func station(identifier: CoastalStationIdentifier) -> Self {
    Self(resolution: .station(identifier))
  }
}

extension TidesRequest where Response == CoastalStations {
  /// Describes one directory response in provider order.
  /// - Parameter query: The validated station category.
  /// - Returns: A request that keeps the directory envelope.
  public static func stations(matching query: CoastalStationQuery) -> Self {
    Self(endpoint: .stations(matching: query))
  }
}

extension TidesRequest where Response == HighLowTides {
  /// Describes high/low predictions with immutable requested context.
  /// - Parameter query: The validated explicit GMT query.
  /// - Returns: A reusable request that attaches context after direct wire decoding.
  public static func highLowTides(matching query: HighLowTideQuery) -> Self {
    Self(resolution: .highLowTides(query))
  }
}

extension TidesRequest where Response == TidePredictions {
  /// Describes sampled tide predictions with immutable requested context.
  /// - Parameter query: The validated explicit GMT query.
  /// - Returns: A reusable request that attaches context after direct wire decoding.
  public static func tidePredictions(matching query: TidePredictionQuery) -> Self {
    Self(resolution: .tidePredictions(query))
  }
}

extension TidesRequest where Response == WaterLevels {
  /// Describes six-minute measurements with immutable requested context.
  /// - Parameter query: The validated explicit GMT query.
  /// - Returns: A reusable request that attaches context after direct wire decoding.
  public static func waterLevels(matching query: WaterLevelQuery) -> Self {
    Self(resolution: .waterLevels(query))
  }
}
