# Source verification

- **Retrieval date:** 2026-10-30
- **PoC name:** `fabric-kafka-avro-apicurio-kusto-poc`

## Pinned versions selected

| Component | Selected version | Evidence |
|---|---:|---|
| Kafka runtime | Confluent Platform `8.1.1` (Apache Kafka `4.1.x`) | Confluent compatibility matrix and Kusto sink v5.3.7 build metadata |
| Kafka Connect runtime | `confluentinc/cp-kafka-connect:8.1.1` | Kusto sink v5.3.7 `pom.xml` includes `kafka.version=4.1.1` and `kafka.connect.avro.converter.version=8.1.1` |
| Apicurio Registry | `apicurio/apicurio-registry:3.3.3` | Docker install docs and Maven metadata for 3.3.3 SerDes/converter artifacts |
| Apicurio converter plugin | `apicurio-registry-distro-connect-converter:3.3.3` | Maven metadata + class source for `io.apicurio.registry.utils.converter.AvroConverter` |
| Kusto sink connector | `Azure/kafka-sink-azure-kusto v5.3.7` | GitHub releases API + release assets |

## Integration pattern chosen

- **Producer serializer class:** `io.apicurio.registry.serde.avro.AvroKafkaSerializer`
- **Connect value converter class:** `io.apicurio.registry.utils.converter.AvroConverter`
- **Kafka wire format:** Apicurio registry-aware Avro binary payload (`apicurio.registry.avro.encoding=BINARY`) with ID in payload (`io.apicurio.registry.serde.Default4ByteIdHandler`, headers disabled).
- **Registry URL used in Stage 1:** `http://apicurio:8080/apis/registry/v3`
- **Fallback compatibility mode (documented but not used in Stage 1):** Apicurio ccompat endpoint `/apis/ccompat/v7` with Confluent `KafkaAvroSerializer` + `io.confluent.connect.avro.AvroConverter`.

## Connector auth properties selected

- `aad.auth.strategy=application`
- `aad.auth.authority=<tenant-id>`
- `aad.auth.appid=<service-principal-app-id>`
- `aad.auth.appkey=<service-principal-secret>`
- `kusto.ingestion.url=<Fabric Ingestion URI>`
- `kusto.query.url=<Fabric Query URI>`

## Supported Kafka/Connect evidence

1. Kusto sink README “Major version specifics” documents Confluent Platform alignment and Java requirements.
2. Kusto sink `v5.3.7` `pom.xml` pins:
   - `kafka.version=4.1.1`
   - `kafka.connect.avro.converter.version=8.1.1`
   - `source.java.version=17`
3. Confluent interoperability page maps CP `8.1.x` to Apache Kafka `4.1.x`.

## Fabric endpoint + permission requirements (exact)

- **Endpoint source:** Fabric KQL Database -> **Database details** -> copy:
  - **Query URI** (for queries and management commands)
  - **Ingestion URI** (for ingestion target)
- **Workspace/API permissions:** Fabric REST Item create requires workspace **Contributor** role and item scopes (`Item.ReadWrite.All` or item-specific).
- **REST create endpoints used in this lab:**
  - `POST /v1/workspaces/{workspaceId}/eventhouses`
  - `POST /v1/workspaces/{workspaceId}/kqlDatabases` with `creationPayload.databaseType=ReadWrite` and `creationPayload.parentEventhouseItemId=<eventhouseId>`
  - `GET /v1/workspaces/{workspaceId}/kqlDatabases/{kqlDatabaseId}` to resolve `properties.queryServiceUri` and `properties.ingestionServiceUri`
- **Kusto DB authorization for sink principal:** add database principal with:
  - `.add database <db> admins ('aadapp=<appId>;<tenantId>') 'kusto sink app'`

## Downloaded plugin archives and SHA-256

| Artifact | URL | SHA-256 |
|---|---|---|
| Kusto sink plugin zip | `https://github.com/Azure/kafka-sink-azure-kusto/releases/download/v5.3.7/microsoftcorporation-kafka-sink-azure-kusto-5.3.7.zip` | `482b545145c0bb46b662a07766897e81af24711c3345192596218472724dacd6` |
| Apicurio connect converter distro zip | `https://repo1.maven.org/maven2/io/apicurio/apicurio-registry-distro-connect-converter/3.3.3/apicurio-registry-distro-connect-converter-3.3.3.zip` | `1e180d3f2404c4ea4d3909f00e079d0b5d7967d0050a6795ab07c1b41783e372` |

## Authoritative sources used

- Kusto sink repo: https://github.com/Azure/kafka-sink-azure-kusto
- Kusto sink README (raw): https://raw.githubusercontent.com/Azure/kafka-sink-azure-kusto/master/README.md
- Kusto sink release metadata: https://api.github.com/repos/Azure/kafka-sink-azure-kusto/releases
- Kusto sink `v5.3.7` build file: https://raw.githubusercontent.com/Azure/kafka-sink-azure-kusto/v5.3.7/pom.xml
- ADX/Fabric Kafka ingest guide: https://learn.microsoft.com/en-us/azure/data-explorer/ingest-data-kafka
- Fabric Kafka get-data guide: https://learn.microsoft.com/en-us/fabric/real-time-intelligence/get-data-kafka
- Fabric Eventhouse: https://learn.microsoft.com/en-us/fabric/real-time-intelligence/eventhouse
- Fabric create Eventhouse: https://learn.microsoft.com/en-us/fabric/real-time-intelligence/create-eventhouse
- Fabric create KQL DB: https://learn.microsoft.com/en-us/fabric/real-time-intelligence/create-database
- Fabric copy Query/Ingestion URI: https://learn.microsoft.com/en-us/fabric/real-time-intelligence/access-database-copy-uri
- Fabric REST create item: https://learn.microsoft.com/en-us/rest/api/fabric/core/items/create-item
- Fabric REST item management overview: https://learn.microsoft.com/en-us/rest/api/fabric/articles/item-management/item-management-overview
- Kusto JSON mapping: https://learn.microsoft.com/en-us/kusto/management/json-mapping?view=microsoft-fabric
- Kusto AVRO mapping: https://learn.microsoft.com/en-us/kusto/management/avro-mapping?view=microsoft-fabric
- Apicurio SerDes config: https://raw.githubusercontent.com/Apicurio/apicurio-registry/main/docs/modules/ROOT/pages/getting-started/assembly-configuring-kafka-client-serdes.adoc
- Apicurio using SerDes: https://raw.githubusercontent.com/Apicurio/apicurio-registry/main/docs/modules/ROOT/pages/getting-started/assembly-using-kafka-client-serdes.adoc
- Apicurio Confluent compatibility API: https://raw.githubusercontent.com/Apicurio/apicurio-registry/main/docs/modules/ROOT/pages/getting-started/assembly-confluent-schema-registry-compatibility.adoc
- Apicurio Docker install: https://raw.githubusercontent.com/Apicurio/apicurio-registry/main/docs/modules/ROOT/pages/getting-started/assembly-installing-registry-docker.adoc
- Apicurio `AvroKafkaSerializer` source: https://raw.githubusercontent.com/Apicurio/apicurio-registry/main/serdes/kafka/avro-serde/src/main/java/io/apicurio/registry/serde/avro/AvroKafkaSerializer.java
- Apicurio `AvroConverter` source: https://raw.githubusercontent.com/Apicurio/apicurio-registry/main/utils/converter/src/main/java/io/apicurio/registry/utils/converter/AvroConverter.java
- Apache Kafka Connect sample worker config (`plugin.path`): https://raw.githubusercontent.com/apache/kafka/trunk/config/connect-distributed.properties
- Confluent versions/interoperability: https://docs.confluent.io/platform/current/installation/versions-interoperability.html
