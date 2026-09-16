/// Why a paginated National Weather Service collection could not continue.
public enum NWSPaginationError: Error, Hashable, Sendable {
  /// The next-page value is not an allowed National Weather Service API link.
  case invalidNext(String)

  /// Pagination metadata is present without its required next-page value.
  case missingNext

  /// The next-page value would revisit a page in the same traversal.
  case repeatedNext(String)
}
