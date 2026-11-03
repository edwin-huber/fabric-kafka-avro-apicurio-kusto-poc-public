#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"

require_cmd az
require_cmd curl
require_cmd jq

ENV_FILE="${1:-$ROOT_DIR/config/lab.env}"
source "$ENV_FILE"

require_env FABRIC_WORKSPACE_ID
require_env FABRIC_EVENTHOUSE_NAME
require_env FABRIC_DATABASE_NAME

FABRIC_TOKEN="$(az account get-access-token --resource https://api.fabric.microsoft.com --query accessToken -o tsv)"
AUTH_HEADER=(-H "Authorization: Bearer $FABRIC_TOKEN")
JSON_HEADER=(-H "Content-Type: application/json")

create_eventhouse() {
  local payload
  payload="$(jq -n --arg n "$FABRIC_EVENTHOUSE_NAME" '{displayName:$n,description:"PoC Eventhouse"}')"
  curl -si -X POST "${AUTH_HEADER[@]}" "${JSON_HEADER[@]}" \
    "https://api.fabric.microsoft.com/v1/workspaces/$FABRIC_WORKSPACE_ID/eventhouses" \
    -d "$payload"
}

create_kqldb() {
  local eh_id="$1"
  local payload
  payload="$(jq -n --arg n "$FABRIC_DATABASE_NAME" --arg eh "$eh_id" '{displayName:$n,description:"PoC KQL DB",creationPayload:{databaseType:"ReadWrite",parentEventhouseItemId:$eh}}')"
  curl -si -X POST "${AUTH_HEADER[@]}" "${JSON_HEADER[@]}" \
    "https://api.fabric.microsoft.com/v1/workspaces/$FABRIC_WORKSPACE_ID/kqlDatabases" \
    -d "$payload"
}

extract_or_resolve_item_id() {
  local response="$1"
  local list_endpoint="$2"
  local display_name="$3"
  local status
  status="$(printf '%s' "$response" | head -n1 | awk '{print $2}')"
  if [[ "$status" == "201" ]]; then
    printf '%s' "$response" | sed '1,/^\r$/d' | jq -r '.id'
    return
  fi
  if [[ "$status" != "202" ]]; then
    echo "Unexpected status $status" >&2
    printf '%s\n' "$response" >&2
    exit 1
  fi
  local location
  location="$(printf '%s' "$response" | tr -d '\r' | awk -F': ' 'tolower($1)=="location"{print $2}')"
  if [[ -n "$location" ]]; then
    for _ in $(seq 1 20); do
      sleep 3
      local op
      op="$(curl -fsS "${AUTH_HEADER[@]}" "$location" || true)"
      if [[ -n "$op" ]] && [[ "$(printf '%s' "$op" | jq -r '.status // empty')" == "Succeeded" ]]; then
        break
      fi
    done
  fi
  curl -fsS "${AUTH_HEADER[@]}" "$list_endpoint" \
    | jq -r --arg n "$display_name" '.value[] | select(.displayName==$n) | .id' \
    | head -n1
}

EH_RESPONSE="$(create_eventhouse)"
EH_ID="$(extract_or_resolve_item_id "$EH_RESPONSE" "https://api.fabric.microsoft.com/v1/workspaces/$FABRIC_WORKSPACE_ID/eventhouses" "$FABRIC_EVENTHOUSE_NAME")"
[[ -n "$EH_ID" ]] || { echo "Could not resolve Eventhouse ID" >&2; exit 1; }

DB_RESPONSE="$(create_kqldb "$EH_ID")"
DB_ID="$(extract_or_resolve_item_id "$DB_RESPONSE" "https://api.fabric.microsoft.com/v1/workspaces/$FABRIC_WORKSPACE_ID/kqlDatabases" "$FABRIC_DATABASE_NAME")"
[[ -n "$DB_ID" ]] || { echo "Could not resolve KQL DB ID" >&2; exit 1; }

DB_DETAILS="$(curl -fsS "${AUTH_HEADER[@]}" "https://api.fabric.microsoft.com/v1/workspaces/$FABRIC_WORKSPACE_ID/kqlDatabases/$DB_ID")"
QUERY_URI="$(printf '%s' "$DB_DETAILS" | jq -r '.properties.queryServiceUri')"
INGESTION_URI="$(printf '%s' "$DB_DETAILS" | jq -r '.properties.ingestionServiceUri')"

if [[ -n "${QUERY_URI:-}" && "$QUERY_URI" != "null" ]]; then
  sed -i '' "s|^FABRIC_QUERY_URI=.*|FABRIC_QUERY_URI=$QUERY_URI|" "$ENV_FILE"
fi
if [[ -n "${INGESTION_URI:-}" && "$INGESTION_URI" != "null" ]]; then
  sed -i '' "s|^FABRIC_INGESTION_URI=.*|FABRIC_INGESTION_URI=$INGESTION_URI|" "$ENV_FILE"
fi

jq -n \
  --arg eventhouseId "$EH_ID" \
  --arg kqlDatabaseId "$DB_ID" \
  --arg queryUri "$QUERY_URI" \
  --arg ingestionUri "$INGESTION_URI" \
  '{eventhouseId:$eventhouseId,kqlDatabaseId:$kqlDatabaseId,queryUri:$queryUri,ingestionUri:$ingestionUri}' \
  | tee "$RUNTIME_EVIDENCE_DIR/fabric-item-ids.json"

echo "Created Eventhouse=$EH_ID KQLDatabase=$DB_ID and updated FABRIC_QUERY_URI/FABRIC_INGESTION_URI in $ENV_FILE"
