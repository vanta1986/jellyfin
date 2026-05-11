# Jellyfin Docker Image

FROM mcr.microsoft.com/dotnet/sdk:9.0 AS builder
WORKDIR /src
COPY . ./
RUN dotnet restore Jellyfin.sln && dotnet publish Jellyfin.Server/Jellyfin.Server.csproj -c Release -o /app/publish --no-restore

FROM mcr.microsoft.com/dotnet/aspnet:9.0 AS runtime
RUN apt-get update && apt-get install -y --no-install-recommends libva2 libva-drm2 libdrm2 libxml2 libxslt1.1 libexiv2-27 liblttng-ust1 libcurl4 libfontconfig1 libfreetype6 libssl3 mesa-va-drivers libgl1-mesa-glx && rm -rf /var/lib/apt/lists/*
RUN groupadd -r jellyfin && useradd -r -g jellyfin jellyfin
WORKDIR /config
COPY --from=builder /app/publish ./
RUN mkdir -p /cache && chown -R jellyfin:jellyfin /config /cache
USER jellyfin
EXPOSE 8096 8920
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 CMD curl -f http://localhost:8096/health || exit 1
ENTRYPOINT ["dotnet", "Jellyfin.Server.dll"]
