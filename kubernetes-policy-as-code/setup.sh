#!/usr/bin/env bash

# Isolate setup options, variables and cleanup from the learner's terminal.
(

# Stop on failed commands, unset variables, and failures inside pipelines.
set -euo pipefail

# Keep the controller and CLI on the same reproducible release.
readonly KYVERNO_VERSION="v1.19.1"
readonly RELEASE_URL="https://github.com/kyverno/kyverno/releases/download/${KYVERNO_VERSION}"

# Pin the exercise files to a reviewed repository revision.
readonly TUTORIAL_REPOSITORY="https://github.com/Hasan-Kalzi/kalzi-tbju-kyverno-killercoda.git"
readonly TUTORIAL_COMMIT="9efb0fd4ef2b0d10534d3f876499852f9e603a33"
readonly TUTORIAL_ROOT="/root/kyverno-tutorial"
readonly WORKSPACE_DIR="$TUTORIAL_ROOT/kubernetes-policy-as-code"

# Require the tools used to download the public tutorial repository.
if ! command -v git >/dev/null 2>&1 ||
   ! command -v timeout >/dev/null 2>&1; then
  echo "[setup] Git and timeout are required in this environment." >&2
  exit 1
fi

# Preserve any existing learner files rather than overwriting their workspace.
if [[ -e "$TUTORIAL_ROOT" || -L "$TUTORIAL_ROOT" ]]; then
  echo "[setup] A tutorial workspace already exists at $TUTORIAL_ROOT." >&2
  echo "[setup] Start a fresh scenario to run automatic setup." >&2
  exit 1
fi

# Expected SHA-256 values from the official release assets.
readonly INSTALL_SHA256="d3322cb346d3d42dd0f41e230b0d1d7bc5619960e1c36fdac4d9151d724b88e6"
readonly CLI_SHA256="b38228f367fc0fdc2b08f4c83ea50ac5f16c60ff8d62d76a66157c33c47b70ae"

# This CLI archive is built for the Linux x86_64 Killercoda environment.
if [[ "$(uname -s)" != "Linux" || "$(uname -m)" != "x86_64" ]]; then
  echo "This setup requires Linux x86_64." >&2
  exit 1
fi

# Create an isolated download directory and remove it when the script exits.
SETUP_TEMP_DIR="$(mktemp -d)"
readonly SETUP_TEMP_DIR
trap 'rm -rf -- "$SETUP_TEMP_DIR"' EXIT

echo "[setup] Waiting for the Kubernetes node..."
kubectl wait --for=condition=Ready node --all --timeout=180s

# Download the pinned installation manifest and check its integrity.
echo "[setup] Downloading Kyverno ${KYVERNO_VERSION}..."
curl --fail --location --retry 3 --connect-timeout 15 --max-time 180 \
  --output "$SETUP_TEMP_DIR/install.yaml" \
  "$RELEASE_URL/install.yaml"

printf '%s  %s\n' "$INSTALL_SHA256" "$SETUP_TEMP_DIR/install.yaml" \
  | sha256sum --check -

# Server-side apply avoids storing the large manifest in a last-applied annotation.
kubectl apply --server-side -f "$SETUP_TEMP_DIR/install.yaml"

# Wait for the controllers rather than assuming they are immediately available.
echo "[setup] Waiting for the Kyverno controllers..."
kubectl wait --for=condition=Available deployment --all \
  -n kyverno --timeout=300s

# Download and verify the matching CLI before extracting its executable.
echo "[setup] Installing the Kyverno CLI..."
curl --fail --location --retry 3 --connect-timeout 15 --max-time 180 \
  --output "$SETUP_TEMP_DIR/kyverno-cli.tar.gz" \
  "$RELEASE_URL/kyverno-cli_${KYVERNO_VERSION}_linux_x86_64.tar.gz"

printf '%s  %s\n' "$CLI_SHA256" "$SETUP_TEMP_DIR/kyverno-cli.tar.gz" \
  | sha256sum --check -

tar -xzf "$SETUP_TEMP_DIR/kyverno-cli.tar.gz" -C "$SETUP_TEMP_DIR"

# Install the binary with executable permissions in the command search path.
install -m 0755 "$SETUP_TEMP_DIR/kyverno" /usr/local/bin/kyverno

# Download into temporary storage so an interrupted clone is cleaned up.
echo "[setup] Preparing the tutorial workspace..."
GIT_TERMINAL_PROMPT=0 timeout --kill-after=10s 180s \
  git clone --no-checkout --single-branch --branch main \
  "$TUTORIAL_REPOSITORY" "$SETUP_TEMP_DIR/tutorial"

# Select the pinned commit instead of relying on the current main branch.
git -C "$SETUP_TEMP_DIR/tutorial" checkout --detach "$TUTORIAL_COMMIT"

# Confirm that the checkout represents the revision intended for this scenario.
TUTORIAL_ACTUAL_COMMIT="$(git -C "$SETUP_TEMP_DIR/tutorial" rev-parse HEAD)"
if [[ "$TUTORIAL_ACTUAL_COMMIT" != "$TUTORIAL_COMMIT" ]]; then
  echo "[setup] Unexpected tutorial repository revision." >&2
  exit 1
fi

# Check that every file needed by the exercises is present and non-empty.
for TUTORIAL_REQUIRED_FILE in \
  policy/disallow-hostpath.yaml \
  manifests/insecure-deployment.yaml \
  manifests/secure-deployment.yaml \
  verify-policy.sh \
  verify-rejection.sh \
  verify-deployment.sh; do
  if [[ ! -s "$SETUP_TEMP_DIR/tutorial/kubernetes-policy-as-code/$TUTORIAL_REQUIRED_FILE" ]]; then
    echo "[setup] Missing tutorial file: $TUTORIAL_REQUIRED_FILE" >&2
    exit 1
  fi
done

# Publish the verified checkout at the path used throughout the tutorial.
mv -- "$SETUP_TEMP_DIR/tutorial" "$TUTORIAL_ROOT"
echo "[setup] Tutorial files ready at $WORKSPACE_DIR"
echo "[setup] Tutorial revision: $TUTORIAL_COMMIT"

# Print the actual installed version and controller status for verification.
kyverno version
kubectl get pods -n kyverno
echo "[setup] Installation complete."
)
