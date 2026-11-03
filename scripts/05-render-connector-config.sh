#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"

require_cmd sed
require_cmd grep

ENV_FILE="${1:-$ROOT_DIR/config/lab.env}"
source "$ENV_FILE"

for v in CONNECTOR_NAME KAFKA_TOPIC KUSTO_AUTHORITY_TENANT_ID KUSTO_APP_ID KUSTO_APP_SECRET FABRIC_INGESTION_URI FABRIC_QUERY_URI FABRIC_DATABASE_NAME FABRIC_TABLE_NAME FABRIC_MAPPING_NAME; do
  require_env "$v"
done

OUT_FILE="$GENERATED_DIR/kusto-sink.json"
cp "$ROOT_DIR/config/kusto-sink.template.json" "$OUT_FILE"

escape() { printf '%s' "$1" | sed -e 's/[\/&]/\\&/g'; }
sed -i '' \
  -e "s/__CONNECTOR_NAME__/$(escape "$CONNECTOR_NAME")/g" \
  -e "s/__KAFKA_TOPIC__/$(escape "$KAFKA_TOPIC")/g" \
  -e "s/__KUSTO_AUTHORITY_TENANT_ID__/$(escape "$KUSTO_AUTHORITY_TENANT_ID")/g" \
  -e "s/__KUSTO_APP_ID__/$(escape "$KUSTO_APP_ID")/g" \
  -e "s/__KUSTO_APP_SECRET__/$(escape "$KUSTO_APP_SECRET")/g" \
  -e "s/__FABRIC_INGESTION_URI__/$(escape "$FABRIC_INGESTION_URI")/g" \
  -e "s/__FABRIC_QUERY_URI__/$(escape "$FABRIC_QUERY_URI")/g" \
  -e "s/__FABRIC_DATABASE_NAME__/$(escape "$FABRIC_DATABASE_NAME")/g" \
  -e "s/__FABRIC_TABLE_NAME__/$(escape "$FABRIC_TABLE_NAME")/g" \
  -e "s/__FABRIC_MAPPING_NAME__/$(escape "$FABRIC_MAPPING_NAME")/g" \
  "$OUT_FILE"

echo "Generated $OUT_FILE"
