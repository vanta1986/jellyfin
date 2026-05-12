# Jellyfin Docker Image

FROM mcr.microsoft.com/dotnet/sdk:9.0 AS builder
WORKDIR /repo
COPY . .
ENV DOTNET_CLI_TELEMETRY_OPTOUT=1
RUN dotnet publish Jellyfin.Server --disable-parallel -c Release --self-contained true --runtime linux-x64 -o /app/publish "-p:DebugSymbols=false;DebugType=none"

FROM mcr.microsoft.com/dotnet/aspnet:9.0 AS runtime
RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg \
    libva2 \
    libva-drm2 \
    libdrm2 \
    libxml2 \
    libxslt1.1 \
    libexiv2-27 \
    liblttng-ust1 \
    libcurl4 \
    libfontconfig1 \
    libfreetype6 \
    libssl3 \
    mesa-va-drivers \
    libgl1-mesa-glx \
    && rm -rf /var/lib/apt/lists/*
RUN groupadd -r jellyfin && useradd -r -g jellyfin jellyfin
WORKDIR /app
COPY --from=builder /app/publish /app/
RUN mkdir -p /config /cache && chown -R jellyfin:jellyfin /app /config /cache
USER jellyfin
ENV JELLYFIN_CACHE_DIR=/cache
ENV JELLYFIN_CONFIG_DIR=/config
ENV JELLYFIN_DATA_DIR=/config
ENV JELLYFIN_LOG_DIR=/config/log
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8
EXPOSE 8096 8920
HEALTHCHECK --interval=30s --timeout=30s --start-period=10s --retries=3 CMD curl -Lk http://localhost:8096/health || exit 1
ENTRYPOINT ["/app/jellyfin", \
    "--datadir", "/config", \
    "--cachedir", "/cache"]
