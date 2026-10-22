#!/usr/bin/env bash
# Creates an environment, waits until it is running, and writes env-id,
# env-name and env-url to the step outputs from the CLI's JSON (stdout is
# JSON only; progress goes to stderr). A failed create fails the step with
# the CLI's own exit code.
set -euo pipefail

if [ -z "$ENV_BC_VERSION" ] || [ -z "$ENV_COUNTRY" ]; then
  echo "::error::create: true needs bc-version and country"
  exit 1
fi
if ! command -v jq >/dev/null 2>&1; then
  echo "::error::create needs jq on the runner (preinstalled on GitHub-hosted runners)"
  exit 1
fi

args=(env create --version "$ENV_BC_VERSION" --country "$ENV_COUNTRY" --wait --wait-timeout "$ENV_WAIT_TIMEOUT" -o json)
[ -n "$ENV_NAME" ] && args+=(--name "$ENV_NAME")
[ -n "$ENV_REGION" ] && args+=(--region "$ENV_REGION")

out="${RUNNER_TEMP:-/tmp}/setup-bcdock-env-$$.json"
set +e
bcdock "${args[@]}" > "$out"
rc=$?
set -e
if [ "$rc" -ne 0 ]; then
  echo "::error::bcdock env create failed (exit ${rc})"
  exit "$rc"
fi

id=$(jq -r '.id // empty' "$out")
name=$(jq -r '.name // empty' "$out")
url=$(jq -r '.webClientUrl // empty' "$out")
rm -f "$out"
if [ -z "$id" ] || [ -z "$url" ]; then
  echo "::error::The environment was created but the CLI output had no id or webClientUrl"
  exit 1
fi
{
  echo "env-id=${id}"
  echo "env-name=${name}"
  echo "env-url=${url}"
} >> "$GITHUB_OUTPUT"
echo "Environment ${name} is running: ${url}"
