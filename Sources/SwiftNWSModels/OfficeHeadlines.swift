/// The editorial headlines a forecast office publishes, from `/offices/{officeId}/headlines`.
///
/// Headlines keep the order the service listed them in. An office with nothing to say answers a
/// present but empty list, which decodes as no headlines. A body without a `@graph` array, or with
/// one that is not an array of headlines, fails to decode rather than producing an empty list.
///
/// The route documents no page size or cursor, so this package offers no headline pagination,
/// ordering policy, or filtering by importance or issuance time.
///
/// ```swift
/// let headlines = try await weather.officeHeadlines(officeIdentifier: "EWX")
/// print(headlines.headlines.count)  // 2
/// ```
public struct OfficeHeadlines: Codable, Hashable, Sendable {
  /// The headlines, in the order the service listed them.
  public var headlines: [OfficeHeadline]

  /// Creates a headline list.
  ///
  /// - Parameter headlines: The headlines, in the order they should be kept.
  public init(headlines: [OfficeHeadline]) {
    self.headlines = headlines
  }

  private enum CodingKeys: String, CodingKey {
    case headlines = "@graph"
  }
}
