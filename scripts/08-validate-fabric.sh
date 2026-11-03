#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"

require_cmd az
require_cmd curl
require_cmd jq

ENV_FILE="${1:-$ROOT_DIR/config/lab.env}"
source "$ENV_FILE"

for v in FABRIC_QUERY_URI FABRIC_DATABASE_NAME FABRIC_TABLE_NAME; do
  require_env "$v"
done

KUSTO_TOKEN="$(az account get-access-token --resource https://api.kusto.windows.net --query accessToken -o tsv)"
QUERY_URL="${FABRIC_QUERY_URI%/}/v2/rest/query"
MGMT_URL="${FABRIC_QUERY_URI%/}/v1/rest/mgmt"
QUERY="${FABRIC_TABLE_NAME} | project event_id, event_ts, device_id, temperature_c, status | order by event_id asc"

curl -fsS -X POST "$QUERY_URL" \
  -H "Authorization: Bearer $KUSTO_TOKEN" \
  -H "Content-Type: application/json" \
  -d "$(jq -n --arg db "$FABRIC_DATABASE_NAME" --arg csl "$QUERY" '{db:$db,csl:$csl}')" \
  | tee "$RUNTIME_EVIDENCE_DIR/fabric-query-result.json" >/dev/null

COUNT_QUERY="${FABRIC_TABLE_NAME} | count"
curl -fsS -X POST "$QUERY_URL" \
  -H "Authorization: Bearer $KUSTO_TOKEN" \
  -H "Content-Type: application/json" \
  -d "$(jq -n --arg db "$FABRIC_DATABASE_NAME" --arg csl "$COUNT_QUERY" '{db:$db,csl:$csl}')" \
  | tee "$RUNTIME_EVIDENCE_DIR/fabric-count-result.json" >/dev/null

FAILURES_CMD=".show ingestion failures | where Database == '$FABRIC_DATABASE_NAME' and Table == '$FABRIC_TABLE_NAME' | take 20"
curl -fsS -X POST "$MGMT_URL" \
  -H "Authorization: Bearer $KUSTO_TOKEN" \
  -H "Content-Type: application/json" \
  -d "$(jq -n --arg db "$FABRIC_DATABASE_NAME" --arg c "$FAILURES_CMD" '{db:$db,csl:$c}')" \
  | tee "$RUNTIME_EVIDENCE_DIR/fabric-ingestion-failures.json" >/dev/null

echo "Saved validation results under $RUNTIME_EVIDENCE_DIR"
