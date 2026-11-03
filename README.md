# fabric-kafka-avro-apicurio-kusto-poc-public

Simplified, reproducible end-to-end PoC:

`Avro binary in Kafka -> Apicurio schema resolution in Connect -> Connect Struct -> Kusto sink writer.type=JSON -> Fabric JSON mapping -> typed KQL table`

## Architecture

- **Producer** serializes deterministic records with one fixed Avro schema using `io.apicurio.registry.serde.avro.AvroKafkaSerializer`.
- **Kafka** stores Avro binary payloads.
- **Apicurio Registry** stores/resolves schema via `/apis/registry/v3`.
- **Kafka Connect** uses `io.apicurio.registry.utils.converter.AvroConverter` to deserialize to schema-bearing Connect records.
- **Azure/kafka-sink-azure-kusto** ingests into Fabric KQL DB with JSON format and ingestion mapping.

This proves the Stage 1 nonnegotiable path and **does not** use `ByteArrayConverter` for value payloads.

## Pinned component versions

- Kafka/Connect runtime: `confluentinc/cp-kafka:8.1.1`, `confluentinc/cp-kafka-connect:8.1.1`
- Kusto sink connector: `v5.3.7`
- Apicurio Registry: `3.3.3`
- Apicurio connect converter distro: `3.3.3`
- Producer dependencies:
  - `kafka-clients 4.1.1`
  - `apicurio-registry-avro-serde-kafka 3.3.3`

## Prerequisites

- Docker + Docker Compose
- Azure CLI authenticated with the target tenant/subscription
- `jq`, `curl`
- Fabric workspace with capacity
- macOS host for the existing scripts' BSD `sed -i ''` syntax

This public copy contains source and placeholder configuration only. Credentials,
generated configuration, runtime evidence, and downloaded archives are excluded.
See the [configuration reference](docs/configuration.md) for every placeholder and default.

## Deploy for a new user (end-to-end)

### 1. Sign in and select subscription

```bash
az login
az account set --subscription "<subscription-id-or-name>"
az account show --output table
```

### 2. Create a dedicated Entra app/service principal for the sink

```bash
az ad sp create-for-rbac --name "fabric-kafka-avro-apicurio-kusto-poc-sp-<alias>" --skip-assignment -o json
```

Save from output:
- `appId` -> `KUSTO_APP_ID`
- `password` -> `KUSTO_APP_SECRET`
- `tenant` -> `KUSTO_AUTHORITY_TENANT_ID`

### 3. Prepare lab environment file

```bash
cp config/lab.env.example config/lab.env
chmod 600 config/lab.env
```

Edit only the ignored `config/lab.env`, not the committed example. Replace
`REPLACE_WITH_...` entries using the [configuration reference](docs/configuration.md).
Set at least:
- `FABRIC_WORKSPACE_ID` (target Fabric workspace ID)
- `FABRIC_EVENTHOUSE_NAME` (new Eventhouse name for this run)
- `FABRIC_DATABASE_NAME` (new KQL DB name for this run)
- `KUSTO_AUTHORITY_TENANT_ID`
- `KUSTO_APP_ID`
- `KUSTO_APP_SECRET`

`FABRIC_QUERY_URI` and `FABRIC_INGESTION_URI` are auto-populated by `scripts/03-create-fabric-items.sh`.

### 4. Deploy stack and Fabric items

```bash
./scripts/01-prereqs.sh
./scripts/02-up-local-stack.sh
./scripts/03-create-fabric-items.sh config/lab.env
./scripts/04-setup-kql.sh config/lab.env
./scripts/05-render-connector-config.sh config/lab.env
./scripts/06-register-connector.sh
```

### 5. Run Stage 1 deterministic test

```bash
./scripts/07-run-producer.sh
./scripts/08-validate-fabric.sh config/lab.env
./scripts/09-checkpoints.sh config/lab.env
```

## Expected checkpoints

1. Kafka/Apicurio/Connect healthy.
2. Avro schema artifact exists in Apicurio (`poc/sensor-events-value`).
3. Connector is `RUNNING`.
4. Producer sends exactly 3 deterministic records.
5. Fabric shows no ingestion failures.
6. Query returns exactly 3 rows with expected values.

## Deterministic expected rows

| event_id | event_ts | device_id | temperature_c | status |
|---|---|---|---:|---|
| evt-001 | 2026-01-15T10:00:00Z | sensor-a | 21.5 | ok |
| evt-002 | 2026-01-15T10:01:00Z | sensor-b | 19.2 | warn |
| evt-003 | 2026-01-15T10:02:00Z | sensor-c | 23.8 | ok |

## Validation commands

KQL:

```kusto
PocSensorEvents
| project event_id, event_ts, device_id, temperature_c, status
| order by event_id asc
```

```kusto
PocSensorEvents | count
```

Expected count: `3`

### Validation evidence files

After `scripts/08-validate-fabric.sh`, check:
- `evidence/runtime/fabric-query-result.json`
- `evidence/runtime/fabric-count-result.json`
- `evidence/runtime/fabric-ingestion-failures.json`
- `evidence/runtime/connector-status-initial.json`

## Rerun/reset behavior

- Local stack reset:
  - `./scripts/cleanup-local.sh`
- Rerun:
  - recreate connector
  - resend producer payload
- If you keep existing table rows, count will increase (at-least-once semantics).

## Troubleshooting

See `docs/troubleshooting.md`.

## Stage 2 schema evolution test

```bash
./scripts/10-stage2-compatibility-test.sh config/lab.env
```

This test sets compatibility to backward, checks v2 compatibility, produces v1 replay + v2 records, extends KQL table/mapping for `quality_code`, and writes evidence under `evidence/runtime/`.

Stage 2 success signals:
- `evidence/runtime/stage2-ccompat-get.json` shows `BACKWARD`
- `evidence/runtime/stage2-compatibility-check-v2.json` shows `"is_compatible": true`
- `evidence/runtime/stage2-artifact-versions.json` shows at least two schema versions
- `evidence/runtime/stage2-ingestion-failures.json` has zero rows

## Security limitations (local client-secret auth)

- Client secret is sensitive and written to `generated/kusto-sink.json` for connector creation.
- The response in `evidence/runtime/connector-create.json` can also contain the secret.
- Keep `config/lab.env`, `generated/`, and `evidence/runtime/` private and ignored.
- The local services have no authentication; use a trusted development host/network only.
- Use dedicated lab app registration only.
- Delete local generated config after run (`./scripts/cleanup-local.sh`).
- Cleanup does not erase runtime evidence or revoke cloud credentials. Never share raw evidence or logs.
- If a real secret was previously published, rotate it; this clean copy does not invalidate exposed credentials.

## Cleanup

### Local

- Delete connector
- `docker compose down -v --remove-orphans`
- remove generated credential-bearing files (`generated/kusto-sink.json`)
- keep source/docs; retain runtime evidence only locally and treat it as sensitive

### Cloud

- Delete Fabric KQL Database/Eventhouse/workspace only if created by this lab and explicitly confirmed
- Delete dedicated Entra app/service principal
- Verify secret/credential removal
- Do not delete shared capacity or preexisting workspace resources

## Source links

See `docs/source-verification.md`.
