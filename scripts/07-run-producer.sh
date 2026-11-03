#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"

cd "$ROOT_DIR"
docker compose --profile producer run --rm producer | tee "$RUNTIME_EVIDENCE_DIR/producer.log"
