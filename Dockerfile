# Jellyfin Docker Image
# Multi-stage build for nyanmisaka/jellyfin fork with hardware acceleration

FROM mcr.microsoft.com/dotnet/sdk:9.0 AS builder

WORKDIR /src

# Copy everything
COPY . ./

# Build - self-contained so runtime doesn't need SDK
RUN dotnet restore Jellyfin.sln && \
    dotnet publish Jellyfin.Server/Jellyfin.Server.csproj -c Release -r linux-x64 --self-contained true -o /app/publish --no-restore

# Runtime image
FROM ubuntu:22.04 AS runtime

# Install dependencies for hardware acceleration and .NET runtime
RUN apt-get update && apt-get install -y --no-install-recommends \
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
    wget \
    && rm -rf /var/lib/apt/lists/*

# Install .NET runtime
RUN wget https://dotnetcli.azureedge.net/dotnet/Runtime/9.0.0/dotnet-runtime-9.0.0-linux-x64.tar.gz -O /tmp/dotnet-runtime.tar.gz && \
    mkdir -p /usr/share/dotnet && \
    tar -xf /tmp/dotnet-runtime.tar.gz -C /usr/share/dotnet && \
    ln -s /usr/share/dotnet/dotnet /usr/bin/dotnet && \
    rm /tmp/dotnet-runtime.tar.gz

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
