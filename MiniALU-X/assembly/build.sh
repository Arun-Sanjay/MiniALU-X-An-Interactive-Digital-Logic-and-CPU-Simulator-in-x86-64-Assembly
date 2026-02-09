#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"
make
echo "Built: $(pwd)/bin/minialu-x"

