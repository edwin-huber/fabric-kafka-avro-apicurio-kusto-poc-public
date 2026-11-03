#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/lib.sh"

require_cmd az
require_cmd curl
require_cmd jq
require_cmd docker

ENV_FILE="${1:-$ROOT_DIR/config/lab.env}"
source "$ENV_FILE"

for v in FABRIC_QUERY_URI FABRIC_DATABASE_NAME FABRIC_TABLE_NAME FABRIC_MAPPING_NAME CONNECTOR_NAME KAFKA_TOPIC; do
  require_env "$v"
done

REGISTRY_URL="${APICURIO_REGISTRY_URL:-http://localhost:8080/apis/registry/v3}"
CCOMPAT_URL="${REGISTRY_URL%/apis/registry/v3}/apis/ccompat/v7"
GROUP_ID="${APICURIO_GROUP_ID:-poc}"
ARTIFACT_ID="${APICURIO_ARTIFACT_ID:-sensor-events-value}"
SUBJECT="$ARTIFACT_ID"

KUSTO_TOKEN="$(az account get-access-token --resource https://api.kusto.windows.net --query accessToken -o tsv)"
MGMT_URL="${FABRIC_QUERY_URI%/}/v1/rest/mgmt"
QUERY_URL="${FABRIC_QUERY_URI%/}/v2/rest/query"

echo "Setting subject compatibility to BACKWARD..."
curl -fsS -X PUT "$CCOMPAT_URL/config/$SUBJECT" \
  -H "Content-Type: application/json" \
  -d '{"compatibility":"BACKWARD"}' \
  | tee "$RUNTIME_EVIDENCE_DIR/stage2-ccompat-set.json" >/dev/null

curl -fsS "$CCOMPAT_URL/config/$SUBJECT" \
  | tee "$RUNTIME_EVIDENCE_DIR/stage2-ccompat-get.json" >/dev/null

V2_SCHEMA_JSON="$(jq -c . "$ROOT_DIR/producer/src/main/resources/sensor-event-v2.avsc")"
curl -fsS -X POST "$CCOMPAT_URL/compatibility/subjects/$SUBJECT/versions/latest" \
  -H "Content-Type: application/json" \
  -d "$(jq -n --arg schema "$V2_SCHEMA_JSON" '{schema:$schema}')" \
  | tee "$RUNTIME_EVIDENCE_DIR/stage2-compatibility-check-v2.json" >/dev/null

echo "Resetting target table and extending schema/mapping for quality_code..."
curl -fsS -X POST "$MGMT_URL" \
  -H "Authorization: Bearer $KUSTO_TOKEN" \
  -H "Content-Type: application/json" \
  -d "$(jq -n --arg db "$FABRIC_DATABASE_NAME" --arg csl ".clear table $FABRIC_TABLE_NAME data" '{db:$db,csl:$csl}')" >/dev/null

curl -fsS -X POST "$MGMT_URL" \
  -H "Authorization: Bearer $KUSTO_TOKEN" \
  -H "Content-Type: application/json" \
  -d "$(jq -n --arg db "$FABRIC_DATABASE_NAME" --arg csl ".create-merge table $FABRIC_TABLE_NAME (event_id:string, event_ts:datetime, device_id:string, temperature_c:real, status:string, quality_code:string)" '{db:$db,csl:$csl}')" >/dev/null

curl -fsS -X POST "$MGMT_URL" \
  -H "Authorization: Bearer $KUSTO_TOKEN" \
  -H "Content-Type: application/json" \
  -d "$(jq -n --arg db "$FABRIC_DATABASE_NAME" --arg csl ".create-or-alter table $FABRIC_TABLE_NAME ingestion json mapping '$FABRIC_MAPPING_NAME' '[{\"Column\":\"event_id\",\"Properties\":{\"Path\":\"$.event_id\"}},{\"Column\":\"event_ts\",\"Properties\":{\"Path\":\"$.event_ts\"}},{\"Column\":\"device_id\",\"Properties\":{\"Path\":\"$.device_id\"}},{\"Column\":\"temperature_c\",\"Properties\":{\"Path\":\"$.temperature_c\"}},{\"Column\":\"status\",\"Properties\":{\"Path\":\"$.status\"}},{\"Column\":\"quality_code\",\"Properties\":{\"Path\":\"$.quality_code\"}}]'" '{db:$db,csl:$csl}')" >/dev/null

echo "Producing v1 replay records (post-change baseline)..."
cd "$ROOT_DIR"
docker compose --profile producer run --rm \
  -e PRODUCER_SCENARIO=stage2-v1-replay \
  -e KEY_PREFIX=stage2-v1-key- \
  producer | tee "$RUNTIME_EVIDENCE_DIR/stage2-producer-v1.log"

echo "Producing v2 records with quality_code..."
docker compose --profile producer run --rm \
  -e SCHEMA_RESOURCE=/sensor-event-v2.avsc \
  -e PRODUCER_SCENARIO=stage2-v2 \
  -e KEY_PREFIX=stage2-v2-key- \
  producer | tee "$RUNTIME_EVIDENCE_DIR/stage2-producer-v2.log"

echo "Waiting for connector to consume new records..."
for _ in $(seq 1 40); do
  lag="$(docker exec poc-kafka kafka-consumer-groups --bootstrap-server kafka:9092 --group "connect-$CONNECTOR_NAME" --describe 2>/dev/null | awk 'NR==2{print $6}')"
  if [[ "$lag" == "0" ]]; then
    break
  fi
  sleep 3
done

echo "Collecting stage2 validation evidence..."
STAGE2_QUERY="$FABRIC_TABLE_NAME | where event_id startswith 'evt2-' | project event_id, event_ts, device_id, temperature_c, status, quality_code | order by event_id asc"
STAGE2_COUNT="$FABRIC_TABLE_NAME | where event_id startswith 'evt2-' | count"
STAGE2_FAILS=".show ingestion failures | where Database == '$FABRIC_DATABASE_NAME' and Table == '$FABRIC_TABLE_NAME' | where FailedOn > ago(30m) | take 20"

curl -fsS -X POST "$QUERY_URL" \
  -H "Authorization: Bearer $KUSTO_TOKEN" \
  -H "Content-Type: application/json" \
  -d "$(jq -n --arg db "$FABRIC_DATABASE_NAME" --arg csl "$STAGE2_QUERY" '{db:$db,csl:$csl}')" \
  | tee "$RUNTIME_EVIDENCE_DIR/stage2-query-result.json" >/dev/null

curl -fsS -X POST "$QUERY_URL" \
  -H "Authorization: Bearer $KUSTO_TOKEN" \
  -H "Content-Type: application/json" \
  -d "$(jq -n --arg db "$FABRIC_DATABASE_NAME" --arg csl "$STAGE2_COUNT" '{db:$db,csl:$csl}')" \
  | tee "$RUNTIME_EVIDENCE_DIR/stage2-count-result.json" >/dev/null

curl -fsS -X POST "$MGMT_URL" \
  -H "Authorization: Bearer $KUSTO_TOKEN" \
  -H "Content-Type: application/json" \
  -d "$(jq -n --arg db "$FABRIC_DATABASE_NAME" --arg csl "$STAGE2_FAILS" '{db:$db,csl:$csl}')" \
  | tee "$RUNTIME_EVIDENCE_DIR/stage2-ingestion-failures.json" >/dev/null

curl -fsS "http://localhost:8083/connectors/$CONNECTOR_NAME/status" \
  | tee "$RUNTIME_EVIDENCE_DIR/stage2-connector-status.json" >/dev/null

curl -fsS "$REGISTRY_URL/groups/$GROUP_ID/artifacts/$ARTIFACT_ID/versions" \
  | tee "$RUNTIME_EVIDENCE_DIR/stage2-artifact-versions.json" >/dev/null

STAGE2_COUNT_VALUE="$(jq -r '.[] | select(.TableName=="PrimaryResult") | .Rows[0][0]' "$RUNTIME_EVIDENCE_DIR/stage2-count-result.json")"
STAGE2_FAILURES="$(jq -r '.Tables[0].Rows | length' "$RUNTIME_EVIDENCE_DIR/stage2-ingestion-failures.json")"
ARTIFACT_VERSIONS="$(jq -r '.count // ([.versions[]?] | length)' "$RUNTIME_EVIDENCE_DIR/stage2-artifact-versions.json")"

echo "stage2_rows=$STAGE2_COUNT_VALUE"
echo "stage2_ingestion_failures=$STAGE2_FAILURES"
echo "artifact_versions=$ARTIFACT_VERSIONS"

[[ "$STAGE2_COUNT_VALUE" == "4" ]] || { echo "Expected 4 stage2 rows but got $STAGE2_COUNT_VALUE" >&2; exit 1; }
[[ "$STAGE2_FAILURES" == "0" ]] || { echo "Expected 0 ingestion failures but got $STAGE2_FAILURES" >&2; exit 1; }
