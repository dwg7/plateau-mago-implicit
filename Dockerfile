FROM eclipse-temurin:21-jre-jammy

ARG MAGO_VERSION=1.0.0
ARG MAGO_JAR_SHA256=TBD_VERIFIED_SOURCE_REQUIRED
ARG MAGO_JAR_URL=TBD_VERIFIED_SOURCE_REQUIRED

LABEL org.opencontainers.image.title="plateau-mago-implicit"
LABEL org.opencontainers.image.description="Mago 3DTiler environment for PLATEAU CityGML conversion"
LABEL mago.version="${MAGO_VERSION}"

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Download and verify Mago 3DTiler JAR
# These ARGs must be overridden with real values before use.
RUN if [ "${MAGO_JAR_URL}" = "TBD_VERIFIED_SOURCE_REQUIRED" ]; then \
      echo "ERROR: MAGO_JAR_URL is not set. Resolve TBD_VERIFIED_SOURCE_REQUIRED in config/common.yml and Dockerfile before building." >&2; \
      exit 1; \
    fi && \
    curl -fsSL "${MAGO_JAR_URL}" -o mago-3d-tiler.jar && \
    echo "${MAGO_JAR_SHA256}  mago-3d-tiler.jar" | sha256sum --check --strict

RUN mkdir -p /data/input /data/output

VOLUME ["/data/input", "/data/output"]

ENTRYPOINT ["java", "-jar", "/app/mago-3d-tiler.jar"]
CMD ["--help"]
