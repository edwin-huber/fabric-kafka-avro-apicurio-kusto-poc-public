#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"

require_cmd az
require_cmd curl
require_cmd jq

ENV_FILE="${1:-$ROOT_DIR/config/lab.env}"
source "$ENV_FILE"

require_env FABRIC_QUERY_URI
require_env FABRIC_DATABASE_NAME
require_env FABRIC_TABLE_NAME
require_env FABRIC_MAPPING_NAME
require_env KUSTO_APP_ID
require_env KUSTO_AUTHORITY_TENANT_ID

KUSTO_TOKEN="$(az account get-access-token --resource https://api.kusto.windows.net --query accessToken -o tsv)"
MGMT_URL="${FABRIC_QUERY_URI%/}/v1/rest/mgmt"

run_mgmt() {
  local cmd="$1"
  curl -fsS -X POST "$MGMT_URL" \
    -H "Authorization: Bearer $KUSTO_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$(jq -n --arg db "$FABRIC_DATABASE_NAME" --arg c "$cmd" '{db:$db,csl:$c}')"
}

run_mgmt ".create-merge table $FABRIC_TABLE_NAME (event_id:string, event_ts:datetime, device_id:string, temperature_c:real, status:string)"
run_mgmt ".create-or-alter table $FABRIC_TABLE_NAME ingestion json mapping '$FABRIC_MAPPING_NAME' '[{\"Column\":\"event_id\",\"Properties\":{\"Path\":\"$.event_id\"}},{\"Column\":\"event_ts\",\"Properties\":{\"Path\":\"$.event_ts\"}},{\"Column\":\"device_id\",\"Properties\":{\"Path\":\"$.device_id\"}},{\"Column\":\"temperature_c\",\"Properties\":{\"Path\":\"$.temperature_c\"}},{\"Column\":\"status\",\"Properties\":{\"Path\":\"$.status\"}}]'"
run_mgmt ".add database $FABRIC_DATABASE_NAME admins ('aadapp=$KUSTO_APP_ID;$KUSTO_AUTHORITY_TENANT_ID') 'kusto sink app'"

echo "KQL table, JSON mapping, and DB admin principal are configured."
