#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

pushd "${REPO_ROOT}/rust/macopt-scanner" >/dev/null
cargo build
popd >/dev/null

echo "Built scanner at: ${REPO_ROOT}/rust/macopt-scanner/target/debug/macopt-scanner"
