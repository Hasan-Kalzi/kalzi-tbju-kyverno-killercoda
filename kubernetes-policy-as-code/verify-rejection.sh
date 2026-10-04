#!/usr/bin/env bash

# Stop on unexpected failures while checking the cluster's admission policy.
set -euo pipefail

# Locate the manifest in the scenario workspace.
readonly WORKSPACE_DIR="/root/kyverno-tutorial/kubernetes-policy-as-code"
readonly MANIFEST_FILE="$WORKSPACE_DIR/manifests/insecure-deployment.yaml"

# Require the learner to install a ready policy before checking its behaviour.
TUTORIAL_POLICY_READY="$(kubectl get validatingpolicy disallow-hostpath \
  --request-timeout=15s -o jsonpath='{.status.conditionStatus.ready}')"

if [[ "$TUTORIAL_POLICY_READY" != "true" ]]; then
  echo "[verify] The disallow-hostpath policy is not ready." >&2
  exit 1
fi

# Save the admission response temporarily and remove it when the script exits.
TUTORIAL_REJECTION_TEMP_DIR="$(mktemp -d)"
readonly TUTORIAL_REJECTION_TEMP_DIR
readonly TUTORIAL_REJECTION_LOG="$TUTORIAL_REJECTION_TEMP_DIR/admission.log"
trap 'rm -rf -- "$TUTORIAL_REJECTION_TEMP_DIR"' EXIT

# A server-side dry run invokes admission without persisting the workload.
if kubectl apply --dry-run=server -n default -f "$MANIFEST_FILE" \
  --request-timeout=30s >"$TUTORIAL_REJECTION_LOG" 2>&1; then
  cat "$TUTORIAL_REJECTION_LOG"
  echo "[verify] The hostPath Deployment was unexpectedly allowed." >&2
  exit 1
else
  TUTORIAL_ADMISSION_EXIT_CODE=$?
fi

# Show the actual response so learners can inspect the reason for rejection.
cat "$TUTORIAL_REJECTION_LOG"
echo "[verify] kubectl exit code: $TUTORIAL_ADMISSION_EXIT_CODE"

if [[ "$TUTORIAL_ADMISSION_EXIT_CODE" -ne 1 ]]; then
  echo "[verify] Unexpected kubectl exit code." >&2
  exit 1
fi

# Distinguish the intended policy denial from connection or manifest errors.
if ! grep -Fq 'admission webhook' "$TUTORIAL_REJECTION_LOG" ||
   ! grep -Fq 'Policy disallow-hostpath failed:' "$TUTORIAL_REJECTION_LOG" ||
   ! grep -Fq 'hostPath volumes are forbidden' "$TUTORIAL_REJECTION_LOG"; then
  echo "[verify] The request failed for an unexpected reason." >&2
  exit 1
fi

echo "[verify] Kyverno rejected the hostPath Deployment."