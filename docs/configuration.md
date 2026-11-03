# Configuration reference

This public repository contains no deployed cloud IDs, endpoints, credentials, or
historical runtime evidence. Sensor records, local Docker addresses, the Kafka
cluster ID, and plugin SHA-256 checksums are public demo data, not secrets.

## Private configuration

```bash
cp config/lab.env.example config/lab.env
chmod 600 config/lab.env
az login --tenant "<tenant-id>"
az account set --subscription "<subscription-id-or-name>"
```

Replace `<tenant-id>` with the Entra directory ID for your Fabric environment and
`<subscription-id-or-name>` with your Azure subscription ID or name. Confirm your
selection with `az account show --output table`.

Edit only `config/lab.env`. The scripts source it as Bash: use single-quoted string
values, no spaces around `=`, and proper Bash escaping if a value contains a single
quote. Never source untrusted content. Do not paste credentials into committed
examples, issues, screenshots, or command logs.

### Environment placeholders

| Variable | Placeholder | How to configure |
|---|---|---|
| `AZ_SUBSCRIPTION_ID` | `REPLACE_WITH_SUBSCRIPTION_ID` | Copy `az account show --query id -o tsv`. Context metadata only; scripts use the active CLI account, not this variable to switch subscriptions. |
| `AZ_TENANT_ID` | `REPLACE_WITH_TENANT_ID` | Copy `az account show --query tenantId -o tsv`. Context metadata only; select the tenant using `az login --tenant`. |
| `FABRIC_WORKSPACE_ID` | `REPLACE_WITH_FABRIC_WORKSPACE_ID` | Copy the workspace GUID from your Fabric workspace URL, `/groups/<workspace-id>/...`. Use that GUID, not a database/item ID. The workspace needs capacity and your user needs item-creation permissions. |
| `FABRIC_QUERY_URI` | `REPLACE_WITH_FABRIC_QUERY_URI` | Script 03 fills this automatically. For an existing KQL database, copy its exact **Query URI** from **Database details**. Use the HTTPS base URI without a REST API path. |
| `FABRIC_INGESTION_URI` | `REPLACE_WITH_FABRIC_INGESTION_URI` | Script 03 fills this automatically. Otherwise copy the exact **Ingestion URI** from the same database details. Do not derive it from the Query URI. |
| `KUSTO_APP_ID` | `REPLACE_WITH_APPLICATION_CLIENT_ID` | Dedicated Entra application's **Application (client) ID**: `appId` in the creation output below. Not its object ID. |
| `KUSTO_APP_SECRET` | `REPLACE_WITH_CLIENT_SECRET_VALUE` | Client-secret **Value**, shown only when created: `password` in the output below. Not the secret ID. |
| `KUSTO_AUTHORITY_TENANT_ID` | `REPLACE_WITH_APPLICATION_TENANT_ID` | Application's **Directory (tenant) ID**: `tenant` in the creation output below. Use the tenant in which the sink principal is authorized. |

IDs and endpoints are metadata rather than passwords, but placeholders avoid
publishing your deployment context. The client secret is a credential. Required
values still starting with `REPLACE_WITH_` are rejected by the scripts. Leave the
two URI placeholders until script 03 fills them, or set both manually.

### Create the sink application

```bash
az ad sp create-for-rbac \
  --name "fabric-kafka-avro-apicurio-kusto-poc-sp-<alias>" \
  --skip-assignment -o json
```

Replace `<alias>` with an arbitrary lab suffix, not a person's or customer's name.
Run only if authorized to create applications in the selected tenant. The output
contains the secret; do not capture it in public logs. Transfer `appId`, `password`,
and `tenant` to the corresponding `KUSTO_*` entries locally. Alternatively, create
a dedicated application and short-lived secret in the Entra portal and copy those
same values. Revoke the secret when the lab ends.

The CLI user creates Fabric items and executes setup/query commands. The sink uses
the separate application credential. Application creation alone grants no Fabric
access. Your user needs workspace/item permissions and database authorization for
setup; tenant policy may require administrator approval for application access.
Script 04 grants the sink application database admin for this lab, so use a
dedicated lab database, not a shared or production database.

## Safe defaults

These are synthetic names, not redacted private values. Keep them for the standard flow.

| Variable | Default | Configuration guidance |
|---|---|---|
| `FABRIC_EVENTHOUSE_NAME` | `fabric-kafka-avro-apicurio-kusto-eh` | Display name created by script 03. Choose a new lab name for a separate run. |
| `FABRIC_DATABASE_NAME` | `fabric_kafka_avro_poc_db` | KQL database name used throughout. Use its exact name for an existing database; keep a simple identifier suitable for KQL commands. |
| `FABRIC_TABLE_NAME` | `PocSensorEvents` | Table created by script 04. Keep a simple KQL identifier with matching case in queries. |
| `FABRIC_MAPPING_NAME` | `PocSensorEventsJsonMapping` | JSON mapping created by script 04; use the same name when rendering the connector. |
| `CONNECTOR_NAME` | `fabric-kusto-sink-poc` | Kafka Connect name. If changed, supply matching `CONNECTOR_NAME` to cleanup, which does not source `lab.env`. |
| `KAFKA_TOPIC` | `poc.sensor.events` | Keep for the provided flow. If changed, also update the producer's `KAFKA_TOPIC` in `docker-compose.yml`; `lab.env` alone does not configure the producer. |

Run README commands from the repository root. To use an existing Eventhouse/KQL
database, skip script 03, set the exact database name, and populate both URIs
manually. Otherwise script 03 creates new cloud items.

## Connector template tokens

Do not insert real values into `config/kusto-sink.template.json`. Script 05 renders
these tokens from your private environment into ignored `generated/kusto-sink.json`.

| Template token | Environment entry |
|---|---|
| `__CONNECTOR_NAME__` | `CONNECTOR_NAME` |
| `__KAFKA_TOPIC__` | `KAFKA_TOPIC` |
| `__KUSTO_AUTHORITY_TENANT_ID__` | `KUSTO_AUTHORITY_TENANT_ID` |
| `__KUSTO_APP_ID__` | `KUSTO_APP_ID` |
| `__KUSTO_APP_SECRET__` | `KUSTO_APP_SECRET` |
| `__FABRIC_INGESTION_URI__` | `FABRIC_INGESTION_URI` |
| `__FABRIC_QUERY_URI__` | `FABRIC_QUERY_URI` |
| `__FABRIC_DATABASE_NAME__` | `FABRIC_DATABASE_NAME` |
| `__FABRIC_TABLE_NAME__` | `FABRIC_TABLE_NAME` |
| `__FABRIC_MAPPING_NAME__` | `FABRIC_MAPPING_NAME` |

In the other documentation's auth examples, `<tenant-id>` is the application tenant,
`<service-principal-app-id>` is `KUSTO_APP_ID`, and `<service-principal-secret>` is
`KUSTO_APP_SECRET`. `<Fabric Query URI>` and `<Fabric Ingestion URI>` are the
corresponding URI entries. In KQL examples, `<db>` means `FABRIC_DATABASE_NAME`,
`<appId>` means `KUSTO_APP_ID`, and `<tenantId>` means `KUSTO_AUTHORITY_TENANT_ID`.
REST examples' `{workspaceId}` means your workspace GUID; `{eventhouseId}` and
`{kqlDatabaseId}` mean the corresponding Fabric item IDs returned by the API.
Script 03 stores those IDs only in local runtime evidence.

## Keep private artifacts out of Git

- Never force-add ignored files. Keep `config/lab.env`, `generated/`,
  `evidence/runtime/`, `downloads/`, logs, private keys, and build outputs private.
  The Dockerfile downloads/checksums plugin archives; they need not be committed.
- Generated connector JSON and the connector creation response may both contain
  the secret. Other evidence can contain deployment IDs, endpoints, diagnostics,
  or real data if you change the demo. Do not upload raw artifacts as attachments.
- Inspect `git diff --cached` and `git status --short` before committing.
  Ignore rules do not untrack files already in Git or erase Git history.
- Local services are unauthenticated and publish host ports. Use a trusted
  development host/network; do not expose them on untrusted networks.
- Cleanup deletes the generated connector file, not your environment file, runtime
  evidence, or cloud credentials. Remove private local artifacts when no longer
  needed and revoke the dedicated secret/application separately.
- If a real secret was previously published, revoke/rotate it and address the
  exposed history and other copies. A clean repository does not undo disclosure.
