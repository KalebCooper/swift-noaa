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
