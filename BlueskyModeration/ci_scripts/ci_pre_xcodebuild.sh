#!/bin/sh
# Xcode Cloud pre-build: generate .xcodeproj from project.yml
set -e
cd "$CI_WORKSPACE" || exit 1
export PATH="/usr/local/bin:$PATH"
xcodegen generate
