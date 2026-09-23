import HTTPCore

extension RetryPolicy {
  /// A policy that sends a request again when the National Weather Service answers with a
  /// transient failure.
  ///
  /// Makes at most three attempts. After the first failure it waits one second, after the second
  /// five seconds, with no jitter. A numeric `Retry-After` on the failed response replaces the
  /// scheduled wait. The waits run on the clock the client was created with.
  ///
  /// A failed attempt is retried when the transport timed out or the service answered one of
  /// these statuses:
  ///
  /// - `500` and `503`, which the service's change log records it returning from forecast routes.
  /// - `429`, the conventional status for the rate limit the service documents without naming a
  ///   status. The documentation says a limited request may be retried once the limit clears,
  ///   typically within five seconds, which sets the second wait.
  /// - `502` and `504`, the gateway failures of the service's front end.
  ///
  /// Every other failure is thrown on the first attempt: another `4xx` is a problem the request
  /// must fix, a body that does not decode will not decode again, and cancellation is never
  /// retried. A redirect is never retried; the client follows it as a new request with its own
  /// attempts. Every request this package sends is a `GET`, so sending one again is safe.
  ///
  /// The budget covers one HTTP request. Each step of a multi-request lookup, each redirect hop,
  /// and each page of a sequence has its own, so a request that follows the maximum of five
  /// redirects can send up to eighteen requests. When the last attempt fails, the error is the one
  /// it would have been without retrying: ``NWSError/problem(_:)`` for a problem-details body,
  /// otherwise ``NWSError/transport(_:)``.
  ///
  /// ```swift
  /// let client = NWSClient(
  ///   configuration: NWSConfiguration(userAgent: "(myweatherapp.com, contact@myweatherapp.com)"),
  ///   retryPolicy: .transientServiceFailures
  /// )
  /// ```
  public static let transientServiceFailures = RetryPolicy(
    backoff: BackoffSchedule(delays: [.seconds(1), .seconds(5)]),
    maxAttempts: 3,
    retryable: { attempt in
      attempt.failure.isTimeout
        || [429, 500, 502, 503, 504].contains(attempt.failure.statusCode ?? 0)
    }
  )
}
