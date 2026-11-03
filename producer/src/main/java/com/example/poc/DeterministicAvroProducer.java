package com.example.poc;

import io.apicurio.registry.serde.config.SerdeConfig;
import io.apicurio.registry.serde.avro.AvroKafkaSerializer;
import org.apache.avro.Schema;
import org.apache.avro.generic.GenericData;
import org.apache.avro.generic.GenericRecord;
import org.apache.kafka.clients.producer.KafkaProducer;
import org.apache.kafka.clients.producer.ProducerConfig;
import org.apache.kafka.clients.producer.ProducerRecord;
import org.apache.kafka.common.serialization.StringSerializer;

import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.List;
import java.util.Map;
import java.util.Properties;

public class DeterministicAvroProducer {
    public static void main(String[] args) throws Exception {
        String bootstrap = env("KAFKA_BOOTSTRAP_SERVERS", "kafka:9092");
        String topic = env("KAFKA_TOPIC", "poc.sensor.events");
        String registryUrl = env("APICURIO_REGISTRY_URL", "http://apicurio:8080/apis/registry/v3");
        String groupId = env("APICURIO_GROUP_ID", "poc");
        String artifactId = env("APICURIO_ARTIFACT_ID", "sensor-events-value");
        String autoRegister = env("APICURIO_AUTO_REGISTER", "true");
        String schemaResource = env("SCHEMA_RESOURCE", "/sensor-event.avsc");
        String scenario = env("PRODUCER_SCENARIO", "stage1");
        String keyPrefix = env("KEY_PREFIX", "key-");

        Schema schema = loadSchema(schemaResource);
        List<Map<String, Object>> rows = rowsForScenario(scenario);

        Properties props = new Properties();
        props.put(ProducerConfig.BOOTSTRAP_SERVERS_CONFIG, bootstrap);
        props.put(ProducerConfig.ACKS_CONFIG, "all");
        props.put(ProducerConfig.RETRIES_CONFIG, 10);
        props.put(ProducerConfig.RETRY_BACKOFF_MS_CONFIG, 1000);
        props.put(ProducerConfig.KEY_SERIALIZER_CLASS_CONFIG, StringSerializer.class.getName());
        props.put(ProducerConfig.VALUE_SERIALIZER_CLASS_CONFIG, AvroKafkaSerializer.class.getName());
        props.put(SerdeConfig.REGISTRY_URL, registryUrl);
        props.put(SerdeConfig.EXPLICIT_ARTIFACT_GROUP_ID, groupId);
        props.put(SerdeConfig.EXPLICIT_ARTIFACT_ID, artifactId);
        props.put(SerdeConfig.AUTO_REGISTER_ARTIFACT, autoRegister);
        props.put("apicurio.registry.headers.enabled", "false");
        props.put("apicurio.registry.avro.encoding", "BINARY");
        props.put(SerdeConfig.ID_HANDLER, "io.apicurio.registry.serde.Default4ByteIdHandler");

        try (KafkaProducer<String, Object> producer = new KafkaProducer<>(props)) {
            int i = 0;
            for (Map<String, Object> row : rows) {
                GenericRecord record = toRecord(schema, row);

                String key = keyPrefix + (++i);
                producer.send(new ProducerRecord<>(topic, key, record)).get();
                System.out.println("sent " + key + " -> " + row);
            }
            producer.flush();
        }

        Thread.sleep(Duration.ofSeconds(1).toMillis());
    }

    private static String env(String key, String fallback) {
        String value = System.getenv(key);
        return value == null || value.isBlank() ? fallback : value;
    }

    private static Schema loadSchema(String resourcePath) throws Exception {
        try (InputStream in = DeterministicAvroProducer.class.getResourceAsStream(resourcePath)) {
            if (in == null) {
                throw new IllegalStateException("Schema resource not found: " + resourcePath);
            }
            String schemaText = new String(in.readAllBytes(), StandardCharsets.UTF_8);
            return new Schema.Parser().parse(schemaText);
        }
    }

    private static GenericRecord toRecord(Schema schema, Map<String, Object> row) {
        GenericRecord record = new GenericData.Record(schema);
        for (Schema.Field field : schema.getFields()) {
            String name = field.name();
            if (row.containsKey(name)) {
                record.put(name, row.get(name));
                continue;
            }
            if (isNullable(field.schema())) {
                record.put(name, null);
                continue;
            }
            if (field.hasDefaultValue()) {
                record.put(name, GenericData.get().getDefaultValue(field));
                continue;
            }
            throw new IllegalStateException("Missing required field in row: " + name);
        }
        return record;
    }

    private static boolean isNullable(Schema schema) {
        if (schema.getType() != Schema.Type.UNION) {
            return false;
        }
        for (Schema unionType : schema.getTypes()) {
            if (unionType.getType() == Schema.Type.NULL) {
                return true;
            }
        }
        return false;
    }

    private static List<Map<String, Object>> rowsForScenario(String scenario) {
        if ("stage1".equals(scenario)) {
            return List.of(
                    Map.of("event_id", "evt-001", "event_ts", "2026-01-15T10:00:00Z", "device_id", "sensor-a", "temperature_c", 21.5d, "status", "ok"),
                    Map.of("event_id", "evt-002", "event_ts", "2026-01-15T10:01:00Z", "device_id", "sensor-b", "temperature_c", 19.2d, "status", "warn"),
                    Map.of("event_id", "evt-003", "event_ts", "2026-01-15T10:02:00Z", "device_id", "sensor-c", "temperature_c", 23.8d, "status", "ok")
            );
        }
        if ("stage2-v1-replay".equals(scenario)) {
            return List.of(
                    Map.of("event_id", "evt2-101", "event_ts", "2026-01-15T11:00:00Z", "device_id", "sensor-a", "temperature_c", 21.1d, "status", "ok"),
                    Map.of("event_id", "evt2-102", "event_ts", "2026-01-15T11:01:00Z", "device_id", "sensor-b", "temperature_c", 18.9d, "status", "warn"),
                    Map.of("event_id", "evt2-103", "event_ts", "2026-01-15T11:02:00Z", "device_id", "sensor-c", "temperature_c", 24.2d, "status", "ok")
            );
        }
        if ("stage2-v2".equals(scenario)) {
            return List.of(
                    Map.of(
                            "event_id", "evt2-201",
                            "event_ts", "2026-01-15T11:03:00Z",
                            "device_id", "sensor-d",
                            "temperature_c", 22.4d,
                            "status", "ok",
                            "quality_code", "QC-A")
            );
        }
        throw new IllegalArgumentException("Unsupported PRODUCER_SCENARIO: " + scenario);
    }
}
