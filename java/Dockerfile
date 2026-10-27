#
# see more @ https://docs.spring.io/spring-boot/3.5/reference/packaging/container-images/dockerfiles.html
#

FROM harbor.dev.szad.teehmoon.com/collections/docker.io/library/maven:3.9.14-eclipse-temurin-21-alpine AS builder

WORKDIR /work

COPY settings.xml pom.xml ./

RUN --mount=type=secret,id=cipw,mode=0666 \
    export COMPANY_NEXUS_MAVEN_REPO_PASSWORD=$(cat /run/secrets/cipw); \
    set -eux; \
    mvn -s settings.xml dependency:go-offline -B;

COPY src src

RUN --mount=type=secret,id=cipw,mode=0666 \
    export COMPANY_NEXUS_MAVEN_REPO_PASSWORD=$(cat /run/secrets/cipw); \
    set -eux; \
    mvn -s settings.xml clean package -Dmaven.test.skip=true; \
    rm -rf ~/.m2

FROM harbor.dev.szad.teehmoon.com/collections/docker.io/library/maven:3.9.14-eclipse-temurin-21-alpine AS extractor
WORKDIR /work

ARG JAR_FILE=/work/target/*.jar
COPY --from=builder ${JAR_FILE} app.jar

RUN set -eux; \
    java -Djarmode=tools -jar app.jar extract --layers --destination extracted; \
    rm -rf ${JAR_FILE} app.jar;

FROM harbor.dev.szad.teehmoon.com/collections/gcr.io/distroless/java21-debian13:debug-nonroot

WORKDIR /app

COPY --from=extractor /work/extracted/dependencies/ ./
COPY --from=extractor /work/extracted/snapshot-dependencies/ ./
COPY --from=extractor /work/extracted/spring-boot-loader/ ./
COPY --from=extractor /work/extracted/application/ ./

ENV COMPANY_NEXUS_MAVEN_REPO_USER=

# see @ https://bugs.openjdk.org/browse/JDK-4971166
ENV JAVA_TOOL_OPTIONS="-XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0 -XX:+UseG1GC"

ENTRYPOINT ["java", "-jar", "app.jar"]
