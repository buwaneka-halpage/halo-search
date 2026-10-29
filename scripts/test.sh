#!/bin/zsh
# Runs the unit tests. With full Xcode this is just `swift test`; with only the Command Line Tools,
# Swift Testing ships in a framework folder SwiftPM doesn't search, so point it there.
set -euo pipefail
cd "$(dirname "$0")/.."

if [[ "$(xcode-select -p)" == *CommandLineTools* ]]; then
    FRAMEWORKS=/Library/Developer/CommandLineTools/Library/Developer/Frameworks
    LIBS=/Library/Developer/CommandLineTools/Library/Developer/usr/lib
    exec swift test -Xswiftc -F"$FRAMEWORKS" -Xlinker -F"$FRAMEWORKS" \
        -Xlinker -rpath -Xlinker "$FRAMEWORKS" -Xlinker -rpath -Xlinker "$LIBS" "$@"
fi
exec swift test "$@"
