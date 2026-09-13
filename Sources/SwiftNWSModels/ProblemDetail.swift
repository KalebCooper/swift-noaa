/// The body the API answers a failed request with, as RFC 7807 problem details.
///
/// ```swift
/// let problem = try JSONDecoder().decode(ProblemDetail.self, from: body)
/// print(problem.title)  // "Data Unavailable For Requested Point"
/// ```
public struct ProblemDetail: Codable, Hashable, Sendable {
  /// The identifier the API gave the request. Include it when reporting a problem to the NWS.
  public var correlationId: String

  /// An explanation of this occurrence of the problem.
  public var detail: String

  /// A URI that identifies this occurrence of the problem.
  public var instance: String

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
  ///   - status: The HTTP status code.
  ///   - title: A short summary of the kind of problem.
  ///   - type: A URI that identifies the kind of problem.
  public init(
    correlationId: String,
    detail: String,
    instance: String,
    status: Int,
    title: String,
    type: String
  ) {
    self.correlationId = correlationId
    self.detail = detail
    self.instance = instance
    self.status = status
    self.title = title
    self.type = type
  }
}
