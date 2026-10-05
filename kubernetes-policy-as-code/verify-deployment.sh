#!/usr/bin/env bash

# Stop on unexpected command failures during verification.
set -euo pipefail

# Check the workload created by the learner in the default namespace.
readonly NAMESPACE="default"
readonly DEPLOYMENT_NAME="policy-demo"

# Read one field from the live Deployment, regardless of the working directory.
get_deployment_field() {
  kubectl get deployment "$DEPLOYMENT_NAME" -n "$NAMESPACE" \
    --request-timeout=15s -o "jsonpath=$1"
}

# Reject any hostPath volume, even if the workload is already running.
TUTORIAL_HOSTPATH_VOLUMES="$(get_deployment_field \
  '{.spec.template.spec.volumes[?(@.hostPath)].name}')"

if [[ -n "$TUTORIAL_HOSTPATH_VOLUMES" ]]; then
  echo "[verify] The Deployment still contains a hostPath volume." >&2
  exit 1
fi

# Require the corrected storage type rather than merely removing all volumes.
TUTORIAL_EMPTYDIR_VOLUMES="$(get_deployment_field \
  '{.spec.template.spec.volumes[?(@.emptyDir)].name}')"

if [[ "$TUTORIAL_EMPTYDIR_VOLUMES" != "work-data" ]]; then
  echo "[verify] Expected an emptyDir volume named work-data." >&2
  exit 1
fi

# Confirm that the demo container actually mounts the corrected volume.
TUTORIAL_MOUNT_PATH="$(get_deployment_field \
  '{.spec.template.spec.containers[?(@.name=="demo")].volumeMounts[?(@.name=="work-data")].mountPath}')"

if [[ "$TUTORIAL_MOUNT_PATH" != "/work" ]]; then
  echo "[verify] The demo container must mount work-data at /work." >&2
  exit 1
fi

# Wait for the corrected Pod to become available, with a bounded timeout.
kubectl rollout status deployment/"$DEPLOYMENT_NAME" -n "$NAMESPACE" \
  --timeout=120s --request-timeout=130s

# A scaled-to-zero Deployment must not count as a successful running workload.
TUTORIAL_REPLICA_COUNTS="$(get_deployment_field \
  '{.spec.replicas}/{.status.updatedReplicas}/{.status.readyReplicas}/{.status.availableReplicas}')"

if [[ "$TUTORIAL_REPLICA_COUNTS" != "1/1/1/1" ]]; then
  echo "[verify] Expected one desired, updated, ready and available replica." >&2
  echo "[verify] Actual replica counts: $TUTORIAL_REPLICA_COUNTS" >&2
  exit 1
fi

echo "[verify] The corrected Deployment uses emptyDir at /work."
echo "[verify] One updated replica is ready and available."
echo "[verify] Deployment verification passed."
