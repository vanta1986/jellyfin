# Jellyfin Docker Image
# Multi-stage build for nyanmisaka/jellyfin fork with hardware acceleration

FROM mcr.microsoft.com/dotnet/sdk:9.0 AS builder

WORKDIR /src

# Copy solution and project files first for better layer caching
COPY Directory.Build.props Directory.Packages.props ./
COPY Emby.Naming Emby.Naming/
COPY Emby.Photos Emby.Photos/
COPY Jellyfin.Data Jellyfin.Data/
COPY Jellyfin.Api Jellyfin.Api/
COPY Jellyfin.Server Jellyfin.Server/
COPY Jellyfin.Server.Implementations Jellyfin.Server.Implementations/
COPY MediaBrowser.Common MediaBrowser.Common/
COPY MediaBrowser.Controller MediaBrowser.Controller/
COPY MediaBrowser.LocalMetadata MediaBrowser.LocalMetadata/
COPY MediaBrowser.MediaEncoding MediaBrowser.MediaEncoding/
COPY MediaBrowser.Model MediaBrowser.Model/
COPY MediaBrowser.Providers MediaBrowser.Providers/
COPY MediaBrowser.XbmcMetadata MediaBrowser.XbmcMetadata/
COPY Jellyfin.CodeAnalysis Jellyfin.CodeAnalysis/
COPY Jellyfin.Database Jellyfin.Database/
COPY Jellyfin.Drawing.Skia Jellyfin.Drawing.Skia/
COPY Jellyfin.Drawing Jellyfin.Drawing/
COPY Jellyfin.Extensions Jellyfin.Extensions/
COPY Jellyfin.LiveTv Jellyfin.LiveTv/
COPY Jellyfin.MediaEncoding.Hls Jellyfin.MediaEncoding.Hls/
COPY Jellyfin.MediaEncoding.Keyframes Jellyfin.MediaEncoding.Keyframes/
COPY Jellyfin.Networking Jellyfin.Networking/
COPY Jellyfin.sln ./

# Build
RUN dotnet restore Jellyfin.sln && \
    dotnet publish Jellyfin.Server -c Release -o /app/publish --no-restore

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
    libfontconfig1.0 \
    libfreetype6 \
    libssl3 \
    sudo \
    mesa-va-drivers \
    libva-glx2 \
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
