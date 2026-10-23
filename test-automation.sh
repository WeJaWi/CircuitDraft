#!/bin/zsh
set -euo pipefail
cd -- "${0:A:h}"
mkdir -p .build
swiftc -target arm64-apple-macosx14.0 -o .build/AutomationTests Sources/Model.swift Sources/Store.swift Sources/Automation.swift Sources/Drawing.swift Tests/AutomationTests.swift -framework SwiftUI -framework AppKit -framework UniformTypeIdentifiers
.build/AutomationTests
