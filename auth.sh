#!/usr/bin/env bash
# Checks the token with `bcdock auth whoami` and exports BCDOCK_TOKEN to the
# rest of the job, so later steps authenticate without repeating it. The
# token travels by environment only - never on a command line.
set -euo pipefail

if [ -z "${INPUT_TOKEN:-}" ]; then
  echo "::error::The token input is empty. Pass it from a secret: token: \${{ secrets.BCDOCK_TOKEN }}"
  exit 1
fi
case "$INPUT_TOKEN" in
  *$'\n'*|*$'\r'*) echo "::error::The token contains a line break"; exit 1 ;;
esac
echo "::add-mask::${INPUT_TOKEN}"

set +e
BCDOCK_TOKEN="$INPUT_TOKEN" bcdock auth whoami -o json >/dev/null
rc=$?
set -e
if [ "$rc" -ne 0 ]; then
  echo "::error::bcdock could not authenticate with this token (exit ${rc}). Check the secret and its scopes."
  exit "$rc"
fi

{
  delim="BCDOCK_$(od -An -N8 -tx1 /dev/urandom | tr -d ' \n')"
  echo "BCDOCK_TOKEN<<${delim}"
  echo "$INPUT_TOKEN"
  echo "$delim"
} >> "$GITHUB_ENV"
echo "Authenticated."
