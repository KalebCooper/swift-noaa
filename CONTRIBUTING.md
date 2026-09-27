# Contributing to swift-noaa

Issues, documentation improvements, and pull requests are welcome. For a larger addition, open an
issue first so we can agree on the scope.

## Get started

1. Fork and clone the repository.
2. Open the package directory in Xcode 26 or later, using Swift 6.2 or later.
3. Select Xcode's generated `swift-noaa-Package` scheme and run the tests with ⌘U.
   You can also run `swift test` from the package directory.

The [README](README.md) introduces the products and common calls. Each service has two libraries:
models and request descriptions in `SwiftNWSModels` or `SwiftNOAATidesModels`, and client behavior in
`SwiftNWS` or `SwiftNOAATides`. Test targets mirror that layout.

To try an example app, open its project under `Examples/` with the standalone package workspace
closed. The apps use a local reference to this checkout.

## Prepare a pull request

Target `main` and keep each pull request focused on one concern. Include a short description of the
change and how you checked it. Record public API changes under **Unreleased** in [CHANGELOG.md](CHANGELOG.md).

Run the relevant checks from the package directory:

| Check | Command or action |
|---|---|
| Tests | Run the `swift-noaa-Package` scheme in Xcode, or `swift test`. |
| Formatting and repository checks | `bash Scripts/verify.sh` |
| Linux, with and without `HTTPPortable` | `bash Scripts/linux-test.sh` (requires Docker). |
| Documentation | Build all four catalogs as described below. |

`swift format --in-place --recursive Sources Tests` fixes most formatting findings. If you change
`Scripts/verify.sh`, also run `bash Scripts/verify.sh --self-test` and include a failing example for
any new check.

## Library conventions

- **Keep models independent.** Models libraries contain response types, queries, and request values,
  with no third-party networking dependencies. Clients provide execution and other behavior.
- **Make operations easy to use.** Add a client method, an equivalent reusable request factory, and
  typed endpoints that share the same execution path.
- **Preserve provider data.** Keep unknown codes, missing values, response order, and original text.
  Conversion is explicit; avoid inferring freshness, ordering, or fallback behavior.
- **Keep code portable.** Models use `FoundationEssentials` with a `Foundation` fallback. Guard
  Darwin-only code with `#if canImport(Darwin)` and portable transport code with `#if HTTPPortable`.
- **Use typed errors and structured concurrency.** Clients use `Mutex` or `Atomic` for shared state.
  Inject a `Clock` for timing and map errors at each layer.
- **Follow the surrounding style.** Order declarations alphabetically within their groupings, with a
  comment for any necessary exception. Avoid force unwraps, `try!`, and `as!` in `Sources/`.

## Tests

Use Swift Testing and recorded responses; tests never call the live API. Fixtures live in each
service's test-support target under `Sources/`. Record NWS responses with the User-Agent
`(swift-noaa, https://github.com/KalebCooper/swift-noaa)` and add a matching `Fixture` case. Tides
recordings also have a [fixture guide](Sources/SwiftNOAATidesTestSupport/Fixtures/README.md).

Each suite uses `.timeLimit(.minutes(suiteTimeLimitMinutes))` so a stalled test fails instead of
holding the run open.

## Documentation

Write public symbol comments with a one-sentence summary, relevant behavior, and the specific error
cases the operation throws. Put detailed examples and service constraints in the matching DocC
guide. Keep the README a brief introduction with links to those guides.

To build the site locally, first build all four library products for an iOS simulator using the
`swift-noaa-Package` scheme. Then run:

```sh
bash Scripts/build-docs.sh /path/to/Debug-iphonesimulator /tmp/swift-noaa-docs
```

Use the build products directory and a new output directory. The script extracts public symbols,
builds each service's models and client catalogs with warnings treated as errors, and writes the
combined site to the output directory's `site` folder.

## CI and releases

CI tests on Linux, Android, and an iOS simulator, checks formatting, builds the example apps in
Release configuration, and builds the documentation. The documentation site publishes from `main`.

Before tagging a release, run all checks, build the documentation, and build and run the example
apps. Every CI lane must pass on the release commit.

## Report an issue

Include the method or endpoint, expected and actual behavior, and a small reproduction when
possible. Include service problem details if available, with any private information removed.
