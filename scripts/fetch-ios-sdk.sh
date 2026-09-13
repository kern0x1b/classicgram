#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
SDK_DIR="${ROOT_DIR}/build/sdks"

if [ ! -d "${SDK_DIR}/iPhoneOS12.4.sdk" ] && [ ! -d "${SDK_DIR}/iPhoneOS9.3.sdk" ]; then
  echo "[+] Downloading iOS SDKs into build/sdks..."
  mkdir -p "${ROOT_DIR}/build"
  git clone --depth 1 https://github.com/theos/sdks "${SDK_DIR}"
else
  echo "[+] iOS SDKs are present in build/sdks"
fi
