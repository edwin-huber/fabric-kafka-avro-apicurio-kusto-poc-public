#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"

require_cmd curl
require_cmd jq

ENV_FILE="${1:-$ROOT_DIR/config/lab.env}"
source "$ENV_FILE" || true

CONNECT_URL="${CONNECT_URL:-http://localhost:8083}"
TOPIC="${KAFKA_TOPIC:-poc.sensor.events}"
CONNECTOR="${CONNECTOR_NAME:-fabric-kusto-sink-poc}"

echo "checkpoint-1 local stack reachable"
curl -fsS http://localhost:8083/connectors >/dev/null
curl -fsS http://localhost:8080/apis/registry/v3/groups >/dev/null

echo "checkpoint-2 schema artifact exists"
curl -fsS "http://localhost:8080/apis/registry/v3/groups/poc/artifacts/sensor-events-value" | jq -r '.artifactId'

echo "checkpoint-3 connector running"
curl -fsS "$CONNECT_URL/connectors/$CONNECTOR/status" | jq '.connector.state,.tasks[0].state'

echo "checkpoint-4 topic has produced offsets"
docker exec poc-kafka kafka-consumer-groups --bootstrap-server kafka:9092 --group "connect-$CONNECTOR" --describe || true

echo "checkpoint-5 no ingestion failures"
if [[ -f "$RUNTIME_EVIDENCE_DIR/fabric-ingestion-failures.json" ]]; then
  jq '.Tables[0].Rows | length' "$RUNTIME_EVIDENCE_DIR/fabric-ingestion-failures.json"
else
  echo "missing $RUNTIME_EVIDENCE_DIR/fabric-ingestion-failures.json"
fi

echo "checkpoint-6 deterministic row count"
if [[ -f "$RUNTIME_EVIDENCE_DIR/fabric-count-result.json" ]]; then
  jq '.[] | select(.TableName=="PrimaryResult") | .Rows[0][0]' "$RUNTIME_EVIDENCE_DIR/fabric-count-result.json"
else
  echo "missing $RUNTIME_EVIDENCE_DIR/fabric-count-result.json"
fi
