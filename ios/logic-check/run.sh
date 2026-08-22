#!/usr/bin/env bash
# Runs the money arithmetic against a plain Swift toolchain — no Xcode, no Mac.
#
# Everything in Tallyroll that decides an amount is Foundation-only on purpose,
# so it can be checked here in about a second instead of waiting on a macOS
# runner. Anything importing SwiftUI or UIKit is out of scope and is covered by
# the iOS job instead.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP="$HERE/../Tallyroll"

rm -rf "$HERE/Sources/Tallyroll" "$HERE/Tests/TallyrollTests"
mkdir -p "$HERE/Sources/Tallyroll" "$HERE/Tests/TallyrollTests"

for f in Money Models Totals; do
  cp "$APP/Sources/Model/$f.swift" "$HERE/Sources/Tallyroll/"
done
cp "$APP/Sources/Support/CSVExport.swift" "$HERE/Sources/Tallyroll/"

for f in MoneyTests RegisterTests CSVExportTests; do
  cp "$APP/Tests/$f.swift" "$HERE/Tests/TallyrollTests/"
done

cd "$HERE"
swift test "$@"
