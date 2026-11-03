#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"

CONNECT_URL="${CONNECT_URL:-http://localhost:8083}"
CONNECTOR_NAME="${CONNECTOR_NAME:-fabric-kusto-sink-poc}"

curl -fsS -X DELETE "$CONNECT_URL/connectors/$CONNECTOR_NAME" >/dev/null || true
cd "$ROOT_DIR"
docker compose down -v --remove-orphans
rm -f "$GENERATED_DIR"/kusto-sink.json

echo "Local cleanup completed."
