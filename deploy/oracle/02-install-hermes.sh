#!/usr/bin/env bash
# Install Hermes Agent (Nous Research). Run as ubuntu on the A1 VM (aarch64).
# Docs: https://hermes-agent.nousresearch.com/docs/getting-started/installation
set -euo pipefail

# Prereq: Git (installer downloads Node as .tar.xz -> also needs curl + xz-utils)
sudo apt install -y git curl xz-utils

# Canonical shell installer (sets up uv, Python, venv, launcher). Also works via
# raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh
curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash
# shellcheck disable=SC1090
source "$HOME/.bashrc" || true

hermes --version
hermes doctor

# Next (config, not run here): FreeLLM as custom endpoint + Telegram gateway
#   hermes model          # provider = custom endpoint -> OPENAI_BASE_URL
#   hermes gateway setup  # Telegram token + numeric user id (allowlist)
#   hermes gateway run    # foreground test ; then `hermes gateway install` (service)
echo "OK hermes installed — if doctor fails on aarch64, document UNK-008"
