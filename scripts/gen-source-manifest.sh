#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
MANIFEST_PATH="${ROOT_DIR}/src/sources.manifest"

cd "${ROOT_DIR}"
{
  find src -name '*.m' -not -path 'src/Resources/*'
  find src -name '*.c' -not -path 'src/Resources/*'
} | sort > "${MANIFEST_PATH}"

echo "[+] Wrote $(wc -l < "${MANIFEST_PATH}" | tr -d ' ') entries to src/sources.manifest"
