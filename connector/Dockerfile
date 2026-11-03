ARG CP_KAFKA_CONNECT_TAG=8.0.0
FROM confluentinc/cp-kafka-connect:${CP_KAFKA_CONNECT_TAG}

ARG KUSTO_SINK_VERSION=5.3.7
ARG KUSTO_SINK_ZIP_SHA256
ARG APICURIO_VERSION=3.3.3
ARG APICURIO_ZIP_SHA256

USER root

RUN microdnf install -y unzip && microdnf clean all

RUN set -eux; \
    mkdir -p /opt/connect-plugins/kusto-sink /opt/connect-plugins/apicurio-converter /tmp/downloads; \
    curl -fL "https://github.com/Azure/kafka-sink-azure-kusto/releases/download/v${KUSTO_SINK_VERSION}/microsoftcorporation-kafka-sink-azure-kusto-${KUSTO_SINK_VERSION}.zip" -o /tmp/downloads/kusto-sink.zip; \
    echo "${KUSTO_SINK_ZIP_SHA256}  /tmp/downloads/kusto-sink.zip" | sha256sum -c -; \
    unzip -q /tmp/downloads/kusto-sink.zip -d /opt/connect-plugins/kusto-sink; \
    curl -fL "https://repo1.maven.org/maven2/io/apicurio/apicurio-registry-distro-connect-converter/${APICURIO_VERSION}/apicurio-registry-distro-connect-converter-${APICURIO_VERSION}.zip" -o /tmp/downloads/apicurio-converter.zip; \
    echo "${APICURIO_ZIP_SHA256}  /tmp/downloads/apicurio-converter.zip" | sha256sum -c -; \
    unzip -q /tmp/downloads/apicurio-converter.zip -d /opt/connect-plugins/apicurio-converter; \
    rm -rf /tmp/downloads

USER appuser
