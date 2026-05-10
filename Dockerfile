# Jellyfin Docker Image
# Multi-stage build for nyanmisaka/jellyfin fork with hardware acceleration

FROM mcr.microsoft.com/dotnet/sdk:9.0 AS builder

WORKDIR /src

# Copy everything
COPY . ./

# Build
RUN dotnet restore Jellyfin.sln && \
    dotnet publish Jellyfin.Server/Jellyfin.Server.csproj -c Release -o /app/publish --no-restore

# Runtime image
FROM mcr.microsoft.com/dotnet/aspnet:9.0 AS runtime

# Install dependencies for hardware acceleration
RUN apt-get update && apt-get install -y --no-install-recommends \
    intel-media-va-driver \
    libva2 \
    libva-drm2 \
    intel-gpu-tools \
    libdrm2 \
    libxml2 \
    libxslt1.1 \
    libexiv2-27 \
    liblttng-ust1 \
    libcurl4 \
    libfontconfig1 \
    libfreetype6 \
    libssl3 \
    sudo \
    mesa-va-drivers \
    libgl1-mesa-glx \
    && rm -rf /var/lib/apt/lists/*

# Create jellyfin user
RUN groupadd -r jellyfin && useradd -r -g jellyfin jellyfin

WORKDIR /config

# Copy published files
COPY --from=builder /app/publish ./

# Create cache directory
RUN mkdir -p /cache && chown -R jellyfin:jellyfin /config /cache

USER jellyfin

# Expose default port
EXPOSE 8096 8920

HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8096/health || exit 1

ENTRYPOINT ["dotnet", "Jellyfin.Server.dll"]
