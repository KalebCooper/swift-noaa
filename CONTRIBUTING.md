# Contributing to swift-noaa

Thanks for your interest. Contributions are welcome; every change to the public surface lands in
`CHANGELOG.md`.

## Getting started

1. Fork and clone the repository.
2. Open the package directory in Xcode 26 or later.
3. Build and run tests on the `swift-noaa` scheme (⌘U), or `swift test` from the command line.

## Guidelines

- **Layers:** `SwiftNWSModels` depends on nothing. It never imports swifty-networking, `URLSession`,
  or any transport type; if a type needs one to exist, it belongs in `SwiftNWS`. `SwiftNWS` adds
  behavior, never models.
- **Public API:** every public symbol needs a DocC comment.
- **Portability:** `SwiftNWSModels` imports Foundation only as the fallback to `FoundationEssentials`.
  Darwin-only code sits inside `#if canImport(Darwin)`, and code that uses the portable transport sits
  inside `#if HTTPPortable`. `Scripts/linux-test.sh` runs the suite on Linux in Docker, with the trait
  on and off.
- **Concurrency:** no actors on the client; shared state is `Mutex` or `Atomic`. Errors are typed and
  mapped at each layer. Inject a `Clock`; never sleep or read the wall clock.
- **Tests:** Swift Testing only, and never against the live API; decode fixtures recorded from it.
  Every `@Suite` carries `.timeLimit(.minutes(suiteTimeLimitMinutes))`, so a test that stops making
  progress fails its suite instead of holding the run open.
- **Style:** `swift format lint --strict --recursive Sources Tests` must report zero findings.
  Declarations are ordered alphabetically within their groupings unless an inline comment says why
  not.
- **Gate:** `Scripts/verify.sh` runs the format lint and every repository invariant the compiler
  cannot see. Run it before every commit; it must exit 0. `Scripts/verify.sh --self-test` proves each
  check still trips on a planted violation.
- **Scope:** no macros, no interceptor or middleware pipelines. Open an issue to discuss additions
  before investing in a large PR.

## Pull requests

Before a release, run the package tests on the shared `swift-noaa` scheme, both Linux configurations
with `Scripts/linux-test.sh`, strict lint, and `Scripts/verify.sh`. Build both DocC catalogs with
warnings treated as errors, then merge and transform them for static hosting. Build and run the demo
with the package window closed in Xcode.

CI repeats Linux, Android, iOS simulator, and lint checks, builds the demo in Release configuration,
and builds documentation on pull requests. Pages publication runs only from `main`. Approve the
release tag after all lanes pass on the release commit; a local pass does not establish hosted or
Android success.

- Target `main`. One concern per PR.
- Update `CHANGELOG.md` under **Unreleased**.

## Reporting issues

Include a minimal reproduction where possible.
