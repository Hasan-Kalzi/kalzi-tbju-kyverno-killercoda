#!/usr/bin/env bash

# Stop if a verification command encounters an unexpected failure.
set -euo pipefail

# Use the same workspace regardless of the caller's current directory.
readonly WORKSPACE_DIR="/root/kyverno-tutorial/kubernetes-policy-as-code"
readonly POLICY_FILE="$WORKSPACE_DIR/policy/disallow-hostpath.yaml"

# Report a missing installation before attempting either policy check.
if ! command -v kyverno >/dev/null 2>&1; then
  echo "[verify] Kyverno CLI is not installed." >&2
  exit 1
fi

# Keep command output in temporary files and clean up when the script exits.
TUTORIAL_CHECK_TEMP_DIR="$(mktemp -d)"
readonly TUTORIAL_CHECK_TEMP_DIR
trap 'rm -rf -- "$TUTORIAL_CHECK_TEMP_DIR"' EXIT

# Check one manifest against both its expected exit code and result counts.
check_manifest() {
  local manifest_file="$1"
  local expected_exit="$2"
  local expected_summary="$3"
  local output_file="$TUTORIAL_CHECK_TEMP_DIR/$(basename -- "$manifest_file").log"
  local actual_exit

  # Capture an expected policy failure without triggering set -e.
  if kyverno apply "$POLICY_FILE" --resource "$manifest_file" \
    --detailed-results --remove-color >"$output_file" 2>&1; then
    actual_exit=0
  else
    actual_exit=$?
  fi

  # Show the evidence so learners can inspect the validation result.
  cat "$output_file"
  echo "[verify] CLI exit code: $actual_exit"

  if [[ "$actual_exit" -ne "$expected_exit" ]]; then
    echo "[verify] Unexpected exit code for $manifest_file." >&2
    return 1
  fi

  # Reject skipped evaluations and technical errors, even if the exit code matches.
  if ! grep -Eq "^$expected_summary[[:space:]]*$" "$output_file"; then
    echo "[verify] Unexpected result counts for $manifest_file." >&2
    return 1
  fi
}

# The hostPath example must produce exactly one policy failure.
check_manifest "$WORKSPACE_DIR/manifests/insecure-deployment.yaml" 1 \
  "pass: 0, fail: 1, warn: 0, error: 0, skip: 0"

# The emptyDir example must produce exactly one successful evaluation.
check_manifest "$WORKSPACE_DIR/manifests/secure-deployment.yaml" 0 \
  "pass: 1, fail: 0, warn: 0, error: 0, skip: 0"

echo "[verify] Both policy checks passed."
