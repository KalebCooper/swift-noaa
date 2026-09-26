/// An explicit choice of one current bin or NOAA's product-specific default.
///
/// Use `.explicit(4)` or `.providerDefault`. Queries reject nonpositive numbers;
/// all-bin access and historical deployment interpretation are not supported.
public enum CurrentBinSelection: Hashable, Sendable {
  /// Requests one positive bin number; availability remains a provider decision.
  case explicit(Int)
  /// Omits the bin parameter. PORTS observations use a predefined bin; other observations may refuse it.
  /// Predictions use the bin nearest the surface. Returned records retain their actual bin.
  case providerDefault

  var queryValue: String? {
    switch self {
    case .explicit(let number): String(number)
    case .providerDefault: nil
    }
  }

  func validate() throws(TidesQueryError) {
    if case .explicit(let number) = self, number <= 0 { throw .invalidBin(number) }
  }
}
