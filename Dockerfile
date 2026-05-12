# Jellyfin Docker Image

FROM mcr.microsoft.com/dotnet/sdk:9.0 AS builder
WORKDIR /repo
COPY . .
ENV DOTNET_CLI_TELEMETRY_OPTOUT=1
RUN dotnet publish Jellyfin.Server --disable-parallel -c Release --self-contained true --runtime linux-x64 -o /jellyfin "-p:DebugSymbols=false;DebugType=none"

FROM debian:stable-slim AS runtime

ARG DEBIAN_FRONTEND=noninteractive
ENV NVIDIA_DRIVER_CAPABILITIES=compute,video,utility \
    LC_ALL=en_US.UTF-8 \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    HEALTHCHECK_URL=http://localhost:8096/health

RUN apt-get update \
 && apt-get install --no-install-recommends --no-install-suggests -y \
    ffmpeg \
    mesa-va-drivers \
    openssl \
    locales \
    curl \
 && sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && locale-gen \
 && apt-get clean autoclean -y \
 && apt-get autoremove -y \
 && rm -rf /var/lib/apt/lists/* \
 && mkdir -p /cache /config /media \
 && chmod 777 /cache /config /media

COPY --from=builder /jellyfin /jellyfin

EXPOSE 8096 8920
VOLUME /cache /config
ENTRYPOINT ["./jellyfin/jellyfin", \
    "--datadir", "/config", \
    "--cachedir", "/cache"]

HEALTHCHECK --interval=30s --timeout=30s --start-period=10s --retries=3 \
     CMD curl -Lk "${HEALTHCHECK_URL}" || exit 1
