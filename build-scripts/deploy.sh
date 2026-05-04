#!/bin/bash
# Deploy build scripts to the target host.
# Configure via environment variables before running:
#   DEPLOY_USER  - SSH username (default: internat)
#   DEPLOY_HOST  - Target host IP or hostname (default: 192.168.122.112)
#   DEPLOY_PATH  - Remote destination path (default: ~/build-scripts)
DEPLOY_USER="${DEPLOY_USER:-internat}"
DEPLOY_HOST="${DEPLOY_HOST:-192.168.122.112}"
DEPLOY_PATH="${DEPLOY_PATH:-~/build-scripts}"

scp -r . "${DEPLOY_USER}@${DEPLOY_HOST}:${DEPLOY_PATH}"
