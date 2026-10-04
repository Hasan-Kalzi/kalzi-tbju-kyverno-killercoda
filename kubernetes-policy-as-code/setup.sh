#!/usr/bin/env bash

# Isolate setup options, variables and cleanup from the learner's terminal.
(

# Stop on failed commands, unset variables, and failures inside pipelines.
set -euo pipefail

# Keep the controller and CLI on the same reproducible release.
readonly KYVERNO_VERSION="v1.19.1"
readonly RELEASE_URL="https://github.com/kyverno/kyverno/releases/download/${KYVERNO_VERSION}"

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

# Print the actual installed version and controller status for verification.
kyverno version
kubectl get pods -n kyverno
echo "[setup] Installation complete."
)