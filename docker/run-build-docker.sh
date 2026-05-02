#!/usr/bin/env bash

#make failing strictier
set -euo pipefail

IMAGE_NAME="luminos-builder"

# Resolve the repo root (one level above this docker/ directory)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Build from the repo root so phases/, assets/, utilities/, services/ are all
# available inside the image, using the Dockerfile that lives in docker/.
docker build -t "$IMAGE_NAME" -f "${SCRIPT_DIR}/Dockerfile" "${REPO_ROOT}"
mkdir -p "${REPO_ROOT}/output"
docker run --rm -v "${REPO_ROOT}/output:/out" "$IMAGE_NAME"
