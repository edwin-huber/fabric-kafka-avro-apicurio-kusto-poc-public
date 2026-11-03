#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"

require_cmd curl
require_cmd jq

CONNECT_URL="${CONNECT_URL:-http://localhost:8083}"
CFG="${1:-$GENERATED_DIR/kusto-sink.json}"

[[ -f "$CFG" ]] || { echo "Missing connector config: $CFG" >&2; exit 1; }

NAME="$(jq -r '.name' "$CFG")"
curl -fsS -X DELETE "$CONNECT_URL/connectors/$NAME" >/dev/null || true
curl -fsS -X POST "$CONNECT_URL/connectors" -H 'Content-Type: application/json' --data @"$CFG" | tee "$RUNTIME_EVIDENCE_DIR/connector-create.json" >/dev/null
curl -fsS "$CONNECT_URL/connectors/$NAME/status" | tee "$RUNTIME_EVIDENCE_DIR/connector-status-initial.json" >/dev/null

echo "Connector posted: $NAME"
