#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
SRC_DIR="${ROOT_DIR}/third_party/openssl/prebuilt/lib"
CRYPTO_UNIVERSAL="${SRC_DIR}/libcrypto-universal.a"
SSL_UNIVERSAL="${SRC_DIR}/libssl-universal.a"

if [ ! -f "${CRYPTO_UNIVERSAL}" ] || [ ! -f "${SSL_UNIVERSAL}" ]; then
  echo "error: ${CRYPTO_UNIVERSAL} or ${SSL_UNIVERSAL} is missing" >&2
  echo "these ship tracked in git at third_party/openssl/prebuilt/lib - a partial or corrupted checkout would be missing them" >&2
  echo "to build fresh ones from source instead: scripts/rebuild-openssl.sh" >&2
  exit 1
fi

for ARCH in armv7 arm64; do
  OUT_DIR="${ROOT_DIR}/build/${ARCH}/libs"
  mkdir -p "${OUT_DIR}"
  lipo "${CRYPTO_UNIVERSAL}" -thin "${ARCH}" -output "${OUT_DIR}/libcrypto.a" 2>/dev/null || cp "${CRYPTO_UNIVERSAL}" "${OUT_DIR}/libcrypto.a"
  lipo "${SSL_UNIVERSAL}" -thin "${ARCH}" -output "${OUT_DIR}/libssl.a" 2>/dev/null || cp "${SSL_UNIVERSAL}" "${OUT_DIR}/libssl.a"
  echo "[+] ${OUT_DIR}/libcrypto.a"
  echo "[+] ${OUT_DIR}/libssl.a"
done
