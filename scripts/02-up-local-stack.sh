#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"

cd "$ROOT_DIR"
docker compose up -d kafka apicurio connect
docker compose ps
