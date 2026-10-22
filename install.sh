#!/usr/bin/env bash
# Installs the bcdock CLI from GitHub Releases on a GitHub Actions runner
# (Linux, macOS or Windows), verifies its checksum, and puts it on PATH.
set -euo pipefail

repo="bcdock/cli"

case "${RUNNER_OS:-}" in
  Linux)   os="linux";   ext="tar.gz" ;;
  macOS)   os="macos";   ext="tar.gz" ;;
  Windows) os="windows"; ext="zip" ;;
  *) echo "::error::Unsupported runner OS: ${RUNNER_OS:-unknown}"; exit 1 ;;
esac

case "${RUNNER_ARCH:-}" in
  X64)   arch="x86_64" ;;
  ARM64) arch="arm64" ;;
  *) echo "::error::Unsupported runner architecture: ${RUNNER_ARCH:-unknown}"; exit 1 ;;
esac
if [ "$os" = "windows" ] && [ "$arch" != "x86_64" ]; then
  echo "::error::bcdock is published for Windows x86_64 only"
  exit 1
fi

version="${BCDOCK_VERSION:-latest}"
if [ -z "$version" ] || [ "$version" = "latest" ]; then
  # Follow the releases/latest redirect instead of calling the REST API:
  # hosted runners share IPs, and the unauthenticated API limit is per IP.
  url=$(curl -fsSLI -o /dev/null -w '%{url_effective}' "https://github.com/${repo}/releases/latest") || {
    echo "::error::Could not resolve the latest bcdock release"
    exit 1
  }
  version="${url##*/}"
fi
version="v${version#v}"
num="${version#v}"
if ! printf '%s' "$num" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+([-.][0-9A-Za-z.]+)?$'; then
  echo "::error::Not a bcdock version: ${version}"
  exit 1
fi

archive="bcdock_${num}_${os}_${arch}.${ext}"
base="https://github.com/${repo}/releases/download/${version}"
tmp="${RUNNER_TEMP:-/tmp}/setup-bcdock-$$"
mkdir -p "$tmp"
trap 'rm -rf "$tmp"' EXIT

echo "Downloading bcdock ${version} (${os}/${arch})"
curl -fsSL --retry 3 -o "${tmp}/${archive}" "${base}/${archive}" || {
  echo "::error::Download failed: ${base}/${archive}"
  exit 1
}
curl -fsSL --retry 3 -o "${tmp}/checksums.txt" "${base}/checksums.txt" || {
  echo "::error::Download failed: ${base}/checksums.txt"
  exit 1
}

expected=$(tr -d '\r' < "${tmp}/checksums.txt" | awk -v f="$archive" '$2 == f {print $1}')
if command -v sha256sum >/dev/null 2>&1; then
  # Hash from stdin: sha256sum escapes a file NAME containing a backslash
  # (every Windows runner path) by prefixing the hash with "\".
  actual=$(sha256sum < "${tmp}/${archive}" | awk '{print $1}')
else
  actual=$(shasum -a 256 < "${tmp}/${archive}" | awk '{print $1}')
fi
if [ -z "$expected" ] || [ "$actual" != "$expected" ]; then
  echo "::error::Checksum mismatch for ${archive}"
  exit 1
fi

dest="${RUNNER_TOOL_CACHE:-${RUNNER_TEMP:-/tmp}}/bcdock/${num}/${arch}"
mkdir -p "$dest"
if [ "$ext" = "zip" ]; then
  if command -v unzip >/dev/null 2>&1; then
    unzip -o -q "${tmp}/${archive}" bcdock.exe -d "$dest"
  else
    pwsh -NoProfile -Command "Expand-Archive -Force -Path '$(cygpath -w "${tmp}/${archive}")' -DestinationPath '$(cygpath -w "$dest")'"
  fi
  bin="${dest}/bcdock.exe"
  path_entry=$(cygpath -w "$dest")
else
  tar -xzf "${tmp}/${archive}" -C "$dest" bcdock
  chmod 755 "${dest}/bcdock"
  bin="${dest}/bcdock"
  path_entry="$dest"
fi

echo "$path_entry" >> "$GITHUB_PATH"
"$bin" version
echo "version=${num}" >> "$GITHUB_OUTPUT"
