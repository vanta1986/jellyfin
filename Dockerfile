# Jellyfin Docker Image

FROM mcr.microsoft.com/dotnet/sdk:9.0 AS builder
WORKDIR /repo
COPY . .
ENV DOTNET_CLI_TELEMETRY_OPTOUT=1
RUN dotnet publish Jellyfin.Server --disable-parallel -c Release --self-contained true --runtime linux-x64 -o /jellyfin "-p:DebugSymbols=false;DebugType=none"

FROM debian:stable-slim AS runtime

ARG DEBIAN_FRONTEND=noninteractive
ARG APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE=DontWarn
ENV NVIDIA_DRIVER_CAPABILITIES=compute,video,utility \
    LC_ALL=en_US.UTF-8 \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    HEALTHCHECK_URL=http://localhost:8096/health

RUN apt-get update \
 && apt-get install --no-install-recommends --no-install-suggests -y \
    ca-certificates \
    gnupg \
    wget \
    apt-transport-https \
    curl \
 && wget -O - https://repo.jellyfin.org/jellyfin_team.gpg.key | apt-key add - \
 && echo "deb [arch=$( dpkg --print-architecture )] https://repo.jellyfin.org/$( awk -F'=' '/^ID=/{ print $NF }' /etc/os-release ) $( awk -F'=' '/^VERSION_CODENAME=/{ print $NF }' /etc/os-release ) main" | tee /etc/apt/sources.list.d/jellyfin.list \
 && apt-get update \
 && apt-get install --no-install-recommends --no-install-suggests -y \
    jellyfin-ffmpeg \
    mesa-va-drivers \
    openssl \
    locales \
 && sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && locale-gen \
 && apt-get remove gnupg wget apt-transport-https -y \
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
    "--cachedir", "/cache", \
    "--ffmpeg", "/usr/lib/jellyfin-ffmpeg/ffmpeg"]

HEALTHCHECK --interval=30s --timeout=30s --start-period=10s --retries=3 \
     CMD curl -Lk "${HEALTHCHECK_URL}" || exit 1
