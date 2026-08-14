# Docker Patterns Reference

> Quick reference for `/infra` phase. Best practices for Dockerfile and docker-compose.

> **Tag discipline.** Images shown with `:latest` or a floating tag (e.g. `myapp:latest`, `aspnet:8.0-alpine`) are **illustrative only**. Real artifacts MUST pin an exact patch tag or digest — no `:latest`, no floating tags (Docker baseline: [`principles-and-practices.md`](../rules/principles-and-practices.md) §4.1 → #4 *Image pinned*; + standing `/scan` rule).

## Dockerfile Best Practices

### Multi-Stage Build (ASP.NET Core)

```dockerfile
# ============================================
# Stage 1: Build
# ============================================
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

# Copy csproj files first (layer caching)
COPY ["src/MyApp.Api/MyApp.Api.csproj", "MyApp.Api/"]
COPY ["src/MyApp.Core/MyApp.Core.csproj", "MyApp.Core/"]
COPY ["src/MyApp.Infrastructure/MyApp.Infrastructure.csproj", "MyApp.Infrastructure/"]

# Restore dependencies (cached if csproj unchanged)
RUN dotnet restore "MyApp.Api/MyApp.Api.csproj"

# Copy everything else
COPY src/ .

# Build
WORKDIR /src/MyApp.Api
RUN dotnet publish -c Release -o /app/publish /p:UseAppHost=false

# ============================================
# Stage 2: Runtime
# ============================================
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS runtime
WORKDIR /app

# Security: Non-root user
RUN addgroup --system --gid 1001 dotnet && \
    adduser --system --uid 1001 appuser --ingroup dotnet
USER appuser

# Copy published app
COPY --from=build /app/publish .

# Configuration
ENV ASPNETCORE_ENVIRONMENT=Production
ENV ASPNETCORE_URLS=http://+:8080
EXPOSE 8080

# Health check
# Probe binary must EXIST in the image: the .NET runtime images ship NO `curl` at all;
# the Debian-based tags ship no `wget` either, alpine has only busybox `wget`. Install what
# you probe with (`apk add --no-cache wget` / `apt-get install -y curl`) or the healthcheck
# fails silently and the container never reaches `healthy`. start-period must outlast
# .NET startup + EF migrations — 5s is not enough.
HEALTHCHECK --interval=30s --timeout=10s --start-period=20s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:8080/health || exit 1

ENTRYPOINT ["dotnet", "MyApp.Api.dll"]
```

---

## Layer Optimization

```
┌─────────────────────────────────────────────────────────────┐
│                    LAYER CACHING                            │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Rarely changes    ─────────────────────────  Cache long    │
│       ↓                                                     │
│  Base image        FROM mcr.microsoft.com/dotnet/sdk:8.0    │
│  Dependencies      COPY *.csproj → RUN dotnet restore       │
│  Source code       COPY . .                                 │
│  Build             RUN dotnet publish                       │
│       ↓                                                     │
│  Frequently changes ─────────────────────── Rebuild often   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Do's and Don'ts

```dockerfile
# ✅ Good: Copy only needed files first
COPY ["*.csproj", "./"]
RUN dotnet restore

COPY . .
RUN dotnet build

# ❌ Bad: Copy everything, lose cache benefit
COPY . .
RUN dotnet restore && dotnet build
```

---

## Security Hardening

### Non-Root User

```dockerfile
# Create non-root user
RUN addgroup --system --gid 1001 dotnet && \
    adduser --system --uid 1001 appuser --ingroup dotnet

# Switch to non-root
USER appuser

# Ensure files are owned correctly
COPY --chown=appuser:dotnet --from=build /app/publish .
```

### Read-Only Filesystem

```yaml
# docker-compose.yml
services:
  api:
    image: myapp:latest
    read_only: true
    tmpfs:
      - /tmp
    security_opt:
      - no-new-privileges:true
```

### Minimal Base Image

```dockerfile
# ✅ Use slim/alpine variants
FROM mcr.microsoft.com/dotnet/aspnet:8.0-alpine
# ⚠️ Alpine .NET defaults to invariant-globalization mode → SqlClient/Npgsql CRASH on
#    connect. Any image with a DB driver MUST add BOTH lines below (see commands/infra.md
#    §Phase 1 for the full runtime stage):
#      RUN apk add --no-cache icu-libs
#      ENV DOTNET_SYSTEM_GLOBALIZATION_INVARIANT=false

# ❌ Avoid full images when not needed
FROM mcr.microsoft.com/dotnet/sdk:8.0
```

---

## Health Checks

### In Dockerfile

```dockerfile
# Probe binary must exist in the image, and start-period must outlast startup + migrations
# (rationale in §Multi-Stage Build above).
HEALTHCHECK --interval=30s --timeout=10s --start-period=20s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:8080/health || exit 1
```

### In docker-compose

```yaml
services:
  api:
    image: myapp:latest
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 20s
```

### Health Check Endpoints

```csharp
// Program.cs
app.MapHealthChecks("/health");           // Basic liveness
app.MapHealthChecks("/health/ready", new HealthCheckOptions
{
    Predicate = check => check.Tags.Contains("ready")
});
```

---

## Docker Compose Patterns

### Development Setup

```yaml
# docker-compose.yml (base — local development; at repo root so `context: .` works)
# No top-level `version:` — obsolete in Compose v2 (emits a warning).

services:
  api:
    build:
      context: .
      dockerfile: docker/Dockerfile
    ports:
      - "5000:5000"
    environment:
      - ASPNETCORE_ENVIRONMENT=Development
      - ConnectionStrings__DefaultConnection=Server=sqlserver;Database=MyApp;User=sa;Password=${SA_PASSWORD};TrustServerCertificate=true
    volumes:
      - ./src:/app/src:ro          # Hot reload
    depends_on:
      sqlserver:
        condition: service_healthy

  sqlserver:
    image: mcr.microsoft.com/mssql/server:2022-CU14-ubuntu-22.04   # pin exact tag — no :latest (§4.1 #4)
    environment:
      - ACCEPT_EULA=Y
      - MSSQL_SA_PASSWORD=${SA_PASSWORD}
    ports:
      - "1433:1433"
    volumes:
      - sqlserver_data:/var/opt/mssql
    healthcheck:
      test: /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "${SA_PASSWORD}" -C -Q "SELECT 1"
      interval: 10s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data

volumes:
  sqlserver_data:
  redis_data:
```

> **arm64 (Apple Silicon / Graviton):** `mcr.microsoft.com/mssql/server` has no arm64 image — use `mcr.microsoft.com/azure-sql-edge:<pinned>` + a TCP-probe healthcheck (Edge ships no sqlcmd).

### Production Setup

```yaml
# docker-compose.deploy.yml (release-tag overlay — at repo root)
# No top-level `version:` — obsolete in Compose v2 (emits a warning).

services:
  api:
    image: ${REGISTRY}/myapp:${VERSION}
    ports:
      - "8080:8080"
    environment:
      - ASPNETCORE_ENVIRONMENT=Production
    env_file:
      - .env.production
    deploy:
      replicas: 3
      resources:
        limits:
          cpus: '1'
          memory: 512M
        reservations:
          cpus: '0.5'
          memory: 256M
      restart_policy:
        condition: on-failure
        delay: 5s
        max_attempts: 3
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 20s
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
```

---

## Service Dependencies

### Wait for Dependencies

```yaml
services:
  api:
    depends_on:
      sqlserver:
        condition: service_healthy
      redis:
        condition: service_started
      kafka:
        condition: service_started
```

### Dependency Health Checks

```yaml
services:
  sqlserver:
    healthcheck:
      test: /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P "${SA_PASSWORD}" -C -Q "SELECT 1"
      interval: 10s
      timeout: 5s
      retries: 5

  redis:
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5

  kafka:
    healthcheck:
      test: kafka-topics --bootstrap-server localhost:9092 --list
      interval: 30s
      timeout: 10s
      retries: 5
```

---

## Environment Variables

### Using .env Files

```bash
# .env
SA_PASSWORD=YourStrong!Password123
REDIS_URL=redis:6379
KAFKA_BROKERS=kafka:9092
```

```yaml
# docker-compose.yml
services:
  api:
    env_file:
      - .env
      - .env.local  # Override for local dev
```

### Secrets Management

```yaml
# docker-compose.yml (Swarm mode)
services:
  api:
    secrets:
      - db_password
      - jwt_secret

secrets:
  db_password:
    external: true
  jwt_secret:
    external: true
```

---

## Networking

### Custom Networks

```yaml
services:
  api:
    networks:
      - frontend
      - backend

  sqlserver:
    networks:
      - backend

  nginx:
    networks:
      - frontend

networks:
  frontend:
    driver: bridge
  backend:
    driver: bridge
    internal: true  # No external access
```

### Port Mapping

```yaml
services:
  api:
    ports:
      - "8080:8080"           # host:container
      - "127.0.0.1:8081:8081" # localhost only
    expose:
      - "9090"                # internal only (no host mapping)
```

---

## Volumes

### Named Volumes (Persistent)

```yaml
services:
  sqlserver:
    volumes:
      - sqlserver_data:/var/opt/mssql

volumes:
  sqlserver_data:
    driver: local
```

### Bind Mounts (Development)

```yaml
services:
  api:
    volumes:
      - ./src:/app/src:ro           # Read-only source
      - ./logs:/app/logs            # Writable logs
      - /app/node_modules           # Anonymous volume (preserve)
```

---

## Common Patterns

### Sidecar Pattern

```yaml
services:
  api:
    image: myapp:latest
    
  # Sidecar for log forwarding
  fluentd:
    image: fluent/fluentd:v1.16
    volumes:
      - ./logs:/var/log/app:ro
```

### Init Container Pattern

```yaml
services:
  migrate:
    image: myapp:latest
    command: ["dotnet", "ef", "database", "update"]
    depends_on:
      sqlserver:
        condition: service_healthy

  api:
    image: myapp:latest
    depends_on:
      migrate:
        condition: service_completed_successfully
```

---

## Commands Reference

```bash
# Build
docker compose build
docker compose build --no-cache

# Run
docker compose up -d
docker compose up -d --scale api=3

# Logs
docker compose logs -f api
docker compose logs --tail=100

# Stop
docker compose down
docker compose down -v  # Remove volumes too

# Exec into container
docker compose exec api sh
docker compose exec sqlserver /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa

# Health check
docker compose ps
docker inspect --format='{{.State.Health.Status}}' container_name
```

---

## Checklist

### Dockerfile
- [ ] Multi-stage build used
- [ ] Non-root user configured
- [ ] Only necessary files copied
- [ ] Layer caching optimized
- [ ] Health check defined
- [ ] Minimal base image

### docker-compose
- [ ] Service dependencies configured
- [ ] Health checks for all services
- [ ] Environment variables externalized
- [ ] Volumes for persistent data
- [ ] Resource limits set (production)
- [ ] Logging configured

### Security
- [ ] No secrets in Dockerfile/compose
- [ ] Non-root user
- [ ] Read-only filesystem (if possible)
- [ ] Minimal privileges
- [ ] Images from trusted sources
