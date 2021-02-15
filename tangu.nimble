# Package

version     = "0.1.0"
author      = "enimatek"
description = "SPA for nim js"
license     = "MIT"

srcDir = "src"
skipDirs = @["tests", "examples"]

# Deps

requires "nim >= 1.4.1"

# Tests

task test, "Runs the test suite.":
  exec "nimble c -y -r tests/tester"
