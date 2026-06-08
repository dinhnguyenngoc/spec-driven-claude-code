# Deployment Checklist

> Quick reference for `/deploy` phase. Verify before releasing to production.

## Pre-Deployment Overview

```
┌─────────────────────────────────────────────────────────────┐
│                  PRE-DEPLOYMENT GATES                       │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  1. CODE        All tests pass, review approved             │
│  2. SECURITY    Scan passed, no critical vulnerabilities    │
│  3. CONFIG      Environment variables set                   │
│  4. INFRA       Docker builds, health checks ready          │
│  5. MONITORING  Dashboards, alerts configured               │
│  6. ROLLBACK    Plan documented and tested                  │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## 1. Code Readiness

### Tests
- [ ] All unit tests pass
- [ ] All integration tests pass
- [ ] E2E tests pass (if applicable)
- [ ] Coverage meets threshold (≥ 80%)
- [ ] No skipped/ignored tests without reason

### Code Review
- [ ] PR approved by reviewer
- [ ] All review comments addressed
- [ ] No merge conflicts
- [ ] Conventional commit messages

### Build
- [ ] Build succeeds without warnings
- [ ] No compiler warnings as errors
- [ ] Assets compiled (frontend bundle)

```bash
# Verify tests
dotnet test --no-build --verbosity normal

# Verify build
dotnet build --configuration Release --no-restore
```

---

## 2. Security Verification

### Vulnerability Scan
- [ ] No critical vulnerabilities
- [ ] No high vulnerabilities (or accepted with ticket)
- [ ] Dependencies up to date

```bash
# Check vulnerable packages
dotnet list package --vulnerable --include-transitive

# Run security scan
semgrep --config=p/csharp --config=p/security-audit .
```

### Secrets
- [ ] No secrets in code (gitleaks check)
- [ ] Environment variables configured in deployment target
- [ ] Secrets rotated if compromised

### Headers & CORS
- [ ] Security headers configured
- [ ] CORS restricted to production domains
- [ ] HTTPS enforced

---

## 3. Configuration

### Environment Variables

```bash
# Required for production
ASPNETCORE_ENVIRONMENT=Production
ASPNETCORE_URLS=http://+:8080

# Database
ConnectionStrings__DefaultConnection=...

# Cache
ConnectionStrings__Redis=...

# Auth
Jwt__Secret=...
Jwt__Issuer=...
Jwt__Audience=...

# Monitoring
Serilog__MinimumLevel__Default=Information
Jaeger__Endpoint=...
```

### Verification
- [ ] All required env vars set
- [ ] Connection strings point to production
- [ ] Feature flags configured
- [ ] Logging level appropriate (Information, not Debug)

---

## 4. Infrastructure

### Docker
- [ ] Dockerfile builds successfully
- [ ] Image tagged with version
- [ ] Image pushed to registry
- [ ] Container runs locally

```bash
# Build and test locally
docker build -t myapp:v1.2.3 -f docker/Dockerfile .
docker run -p 8080:8080 --env-file .env.production myapp:v1.2.3

# Verify health
curl http://localhost:8080/health
```

### Database
- [ ] Migrations tested on staging
- [ ] Migrations are backwards compatible
- [ ] Rollback migration exists (if needed)
- [ ] Backup taken before migration

```bash
# Generate migration script
dotnet ef migrations script --idempotent -o migrations.sql

# Review the SQL before applying
```

### Health Checks
- [ ] `/health` endpoint returns 200
- [ ] `/health/ready` checks all dependencies
- [ ] `/health/live` for liveness probe

---

## 5. Monitoring & Observability

### Logging
- [ ] Structured logging enabled (JSON)
- [ ] Log aggregation configured (Loki/ELK)
- [ ] Correlation IDs propagated
- [ ] No PII in logs

### Metrics
- [ ] Prometheus endpoint exposed (`/metrics`)
- [ ] RED metrics tracked (Rate, Errors, Duration)
- [ ] Business metrics configured

### Dashboards
- [ ] Grafana dashboard exists
- [ ] Key metrics visible
- [ ] Historical data available

### Alerting
- [ ] Alert rules configured
- [ ] On-call notification set up
- [ ] Escalation path defined

| Alert | Threshold | Severity |
|-------|-----------|----------|
| Service down | 1 min | Critical |
| Error rate > 5% | 5 min | Warning |
| P99 latency > 1s | 5 min | Warning |
| CPU > 80% | 10 min | Warning |

---

## 6. Rollback Plan

### Documentation
- [ ] Previous working version identified
- [ ] Rollback steps documented
- [ ] Database rollback plan (if schema changed)
- [ ] Feature flag kill switch ready

### Rollback Procedure

> **Target platform:** per [`tech-stack.md`](../rules/tech-stack.md), Kubernetes is "later" — start with `docker compose`. Use the K8s commands once you have moved to Kubernetes.

```bash
# --- docker compose (default for early-stage deployments) ---

# Pin to previous image tag and roll back
VERSION=v1.2.2 docker compose -f docker-compose.prod.yml up -d

# Verify rollback
docker compose ps
curl -f http://localhost:8080/health

# --- Kubernetes (once migrated) ---

# Quick rollback (revert to previous image)
kubectl rollout undo deployment/myapp

# Or deploy previous version
kubectl set image deployment/myapp myapp=registry/myapp:v1.2.2

# Verify rollback
kubectl rollout status deployment/myapp
```

### Triggers for Rollback
- Error rate > 10%
- P99 latency > 5s
- Health checks failing
- Critical bug discovered

---

## Deployment Strategies

### Rolling Update (Default)

```
┌─────────────────────────────────────────────────────────────┐
│  v1 ████████████████████                                    │
│  v2 ░░░░░░░░░░░░░░░░░░░░████████████████████                │
│                         Gradual replacement                  │
└─────────────────────────────────────────────────────────────┘
```

- Pods replaced one by one
- Zero downtime
- Easy rollback

### Blue-Green

```
┌─────────────────────────────────────────────────────────────┐
│  Blue  (v1) ████████████████████ ← Current                  │
│  Green (v2) ████████████████████ ← Standby                  │
│                                                             │
│  Switch traffic instantly when ready                        │
└─────────────────────────────────────────────────────────────┘
```

- Instant switchover
- Easy rollback (switch back)
- Requires 2x resources

### Canary

```
┌─────────────────────────────────────────────────────────────┐
│  v1 ████████████████████ (90% traffic)                      │
│  v2 ████ (10% traffic) ← Monitor before full rollout        │
└─────────────────────────────────────────────────────────────┘
```

- Test with subset of users
- Gradual traffic increase
- Quick rollback if issues

---

## Post-Deployment Verification

### Immediate (0-5 min)
- [ ] Health check returns 200
- [ ] Key API endpoints respond
- [ ] No error spike in logs
- [ ] Latency within normal range

### Short-term (5-30 min)
- [ ] Monitor error rate
- [ ] Check business metrics (orders, signups)
- [ ] Verify integrations working
- [ ] No customer complaints

### Long-term (1-24 hours)
- [ ] Performance stable
- [ ] No memory leaks
- [ ] No database issues
- [ ] Metrics normal

---

## Deployment Commands

```bash
# --- Build and push image (both targets) ---
docker build -t registry/myapp:v1.2.3 -f docker/Dockerfile .
docker push registry/myapp:v1.2.3

# --- docker compose (default — see tech-stack.md) ---
VERSION=v1.2.3 docker compose -f docker-compose.prod.yml pull
VERSION=v1.2.3 docker compose -f docker-compose.prod.yml up -d
docker compose -f docker-compose.prod.yml ps
docker compose -f docker-compose.prod.yml logs -f --tail=100 api
curl https://api.example.com/health

# Quick rollback if needed
VERSION=v1.2.2 docker compose -f docker-compose.prod.yml up -d

# --- Kubernetes (once migrated) ---
kubectl apply -f k8s/deployment.yaml
kubectl rollout status deployment/myapp
kubectl get pods -l app=myapp
kubectl logs -f -l app=myapp --tail=100
kubectl rollout undo deployment/myapp
```

---

## Checklist Summary

| Phase | Gate | Status |
|-------|------|--------|
| Code | Tests pass, PR approved | ☐ |
| Security | Scan clean, no secrets | ☐ |
| Config | Env vars set | ☐ |
| Infra | Docker builds, migrations ready | ☐ |
| Monitoring | Dashboards, alerts configured | ☐ |
| Rollback | Plan documented | ☐ |
| **GO / NO-GO** | All gates passed | ☐ |
