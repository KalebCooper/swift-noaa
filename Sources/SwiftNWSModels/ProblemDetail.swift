/// The body the API answers a failed request with, as RFC 7807 problem details.
///
/// When the service rejects a request parameter, such as an unknown marine region in a path, it
/// lists each rejection in ``parameterErrors``.
///
/// ```swift
/// let problem = try JSONDecoder().decode(ProblemDetail.self, from: body)
/// print(problem.title)  // "Data Unavailable For Requested Point"
/// for error in problem.parameterErrors ?? [] {
///   print(error.parameter, error.message)
/// }
/// ```
public struct ProblemDetail: Codable, Hashable, Sendable {
  /// One request parameter the service rejected, and why.
  ///
  /// ```swift
  /// let error = problem.parameterErrors?.first
  /// print(error?.parameter ?? "")  // "path.region"
  /// ```
  public struct ParameterError: Codable, Hashable, Sendable {
    /// Why the service rejected the parameter, such as the values it accepts.
    public var message: String

    /// The parameter the service rejected, prefixed by where it appeared, such as `path.region`.
    public var parameter: String

    /// Creates a parameter error.
    ///
    /// - Parameters:
    ///   - message: Why the service rejected the parameter.
    ///   - parameter: The parameter the service rejected.
    public init(message: String, parameter: String) {
      self.message = message
      self.parameter = parameter
    }
  }

  /// The identifier the API gave the request. Include it when reporting a problem to the NWS.
  public var correlationId: String

  /// An explanation of this occurrence of the problem.
  public var detail: String

  /// A URI that identifies this occurrence of the problem.
  public var instance: String

  /// The request parameters the service rejected, in the order it listed them, or `nil` when the
  /// body lists none.
  public var parameterErrors: [ParameterError]?

  /// The HTTP status code of the response.
  public var status: Int

  /// A short summary of the kind of problem, such as `Data Unavailable For Requested Point`.
  public var title: String

  /// A URI that identifies the kind of problem, such as
  /// `https://api.weather.gov/problems/InvalidPoint`.
  public var type: String

  /// Creates problem details.
  ///
  /// - Parameters:
  ///   - correlationId: The identifier the API gave the request.
  ///   - detail: An explanation of this occurrence.
  ///   - instance: A URI that identifies this occurrence.
  ///   - parameterErrors: The request parameters the service rejected.
  ///   - status: The HTTP status code.
  ///   - title: A short summary of the kind of problem.
  ///   - type: A URI that identifies the kind of problem.
  public init(
    correlationId: String,
    detail: String,
    instance: String,
    parameterErrors: [ParameterError]? = nil,
    status: Int,
    title: String,
    type: String
  ) {
    self.correlationId = correlationId
    self.detail = detail
    self.instance = instance
    self.parameterErrors = parameterErrors
    self.status = status
    self.title = title
    self.type = type
  }
}
