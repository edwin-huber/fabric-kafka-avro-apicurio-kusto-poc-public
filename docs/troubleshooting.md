# Troubleshooting

## Entra authentication failure

1. Verify active tenant/subscription:
   - `az account show -o table`
2. Verify service principal values:
   - `KUSTO_AUTHORITY_TENANT_ID`, `KUSTO_APP_ID`, `KUSTO_APP_SECRET`
3. Verify token acquisition:
   - `az account get-access-token --resource https://api.kusto.windows.net`
4. Verify DB principal format exactly:
   - `.add database <db> admins ('aadapp=<appId>;<tenantId>') 'kusto sink app'`

## Fabric endpoint failure

1. Copy **Query URI** and **Ingestion URI** from Fabric KQL DB details card.
2. Do not derive one URI from the other.
3. Ensure:
   - `kusto.query.url` uses Query URI
   - `kusto.ingestion.url` uses Ingestion URI

## Table or mapping failure

1. Check exact names and case:
   - database, table, mapping
2. Check JSON mapping paths and KQL types match payload:
   - `$.event_id`, `$.event_ts`, `$.device_id`, `$.temperature_c`, `$.status`
3. Re-run setup script:
   - `./scripts/04-setup-kql.sh`

## Connector FAILED / task FAILED

1. Retrieve connector status first:
   - `curl -s http://localhost:8083/connectors/$CONNECTOR_NAME/status | jq`
2. Retrieve worker logs:
   - `docker compose logs --no-color connect`
3. Diagnose the first exception before restart.
4. Do not loop restarts without fixing root cause.

## No rows but connector RUNNING

1. Check consumer progress and offsets:
   - `docker exec poc-kafka kafka-consumer-groups --bootstrap-server kafka:9092 --group connect-$CONNECTOR_NAME --describe`
2. Confirm producer sent rows (`evidence/runtime/producer.log`).
3. Check `flush.size.bytes` and `flush.interval.ms`.
4. Query ingestion failures in KQL:
   - `.show ingestion failures`

## Duplicate rows

The Kusto sink is **at-least-once**. Duplicate rows can occur after retries/restarts or replay without reset.

For clean reruns:
1. Delete connector
2. `docker compose down -v --remove-orphans`
3. Truncate or recreate target table
4. Recreate connector and resend deterministic events
