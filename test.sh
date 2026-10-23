#!/bin/zsh
set -euo pipefail
cd -- "${0:A:h}"
mkdir -p .build
swiftc -target arm64-apple-macosx14.0 -o .build/ModelTests Sources/Model.swift Sources/Store.swift Sources/Automation.swift Sources/Drawing.swift Tests/ModelTests.swift -framework SwiftUI -framework AppKit -framework UniformTypeIdentifiers
.build/ModelTests "$PWD/.build/Example.circuitdraft.json"
