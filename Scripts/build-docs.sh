#!/usr/bin/env bash
# Convert only this package's two products from already-built iOS simulator modules.
# Dependencies must compile, but their documentation is not part of this site.
set -euo pipefail

modules="${1:?Usage: bash Scripts/build-docs.sh MODULES_DIRECTORY OUTPUT_DIRECTORY [TARGET]}"
output="${2:?Supply a new output directory}"
sdk="$(xcrun --sdk iphonesimulator --show-sdk-path)"
target="${3:-$(uname -m)-apple-ios26.0-simulator}"

if [[ -e "$output" ]]; then
  echo "Output already exists: $output. Supply a new directory." >&2
  exit 1
fi
mkdir -p "$output/models-symbols" "$output/sdk-symbols" "$output/module-cache"

xcrun swift-symbolgraph-extract -module-name SwiftNWSModels \
  -target "$target" -sdk "$sdk" -I "$modules" \
  -module-cache-path "$output/module-cache" \
  -output-dir "$output/models-symbols" -minimum-access-level public
xcrun docc convert Sources/SwiftNWSModels/SwiftNWSModels.docc \
  --additional-symbol-graph-dir "$output/models-symbols" \
  --output-dir "$output/SwiftNWSModels.doccarchive" \
  --enable-experimental-external-link-support --warnings-as-errors

xcrun swift-symbolgraph-extract -module-name SwiftNWS \
  -target "$target" -sdk "$sdk" -I "$modules" \
  -module-cache-path "$output/module-cache" \
  -output-dir "$output/sdk-symbols" -minimum-access-level public
xcrun docc convert Sources/SwiftNWS/SwiftNWS.docc \
  --additional-symbol-graph-dir "$output/sdk-symbols" \
  --output-dir "$output/SwiftNWS.doccarchive" \
  --enable-experimental-external-link-support \
  --dependency "$output/SwiftNWSModels.doccarchive" --warnings-as-errors

xcrun docc merge "$output/SwiftNWSModels.doccarchive" "$output/SwiftNWS.doccarchive" \
  --synthesized-landing-page-name swift-noaa --synthesized-landing-page-kind Package \
  --output-path "$output/merged.doccarchive"
xcrun docc process-archive transform-for-static-hosting "$output/merged.doccarchive" \
  --output-path "$output/site" --hosting-base-path swift-noaa

# The archive's app shell has no root route under the Pages subpath.
cat > "$output/site/index.html" <<'HTML'
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8">
    <meta http-equiv="refresh" content="0; url=documentation/">
    <link rel="canonical" href="https://kalebcooper.github.io/swift-noaa/documentation/">
    <title>swift-noaa</title>
  </head>
  <body>
    <p>Redirecting to the <a href="documentation/">swift-noaa documentation</a>.</p>
  </body>
</html>
HTML
