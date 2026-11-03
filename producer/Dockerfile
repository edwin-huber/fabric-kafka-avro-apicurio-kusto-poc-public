FROM maven:3.9.9-eclipse-temurin-21 AS build
WORKDIR /src
COPY pom.xml .
COPY src ./src
RUN mvn -q -DskipTests package

FROM eclipse-temurin:21-jre
WORKDIR /app
COPY --from=build /src/target/*-jar-with-dependencies.jar /app/poc-producer.jar
ENTRYPOINT ["java", "-jar", "/app/poc-producer.jar"]
