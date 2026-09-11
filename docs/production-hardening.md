# KisanFlow Production Hardening & Deployment Checklist

## Overview
This document provides complete production hardening instructions, deployment procedures, database scaling recommendations, security controls, and operational guidelines for deploying **KisanFlow** in a live production environment.

---

## 1. Environment & Secrets Management
- [ ] **Secret Management**: Store sensitive keys in AWS Secrets Manager, HashiCorp Vault, or GCP Secret Manager instead of raw `.env` files.
- [ ] **JWT Key Security**: Generate a cryptographically strong 256-bit key (`openssl rand -hex 32`) for `JWT_SECRET`. Rotate every 90 days.
- [ ] **Environment Control**: Ensure `ENVIRONMENT=production` and `DEMO_MODE=false` in all live production instances. Verify `POST /admin/demo-reset` returns `403 Forbidden`.

---

## 2. Database Scaling & Row Locking Strategy
- [ ] **PostgreSQL Deployment**: Use managed PostgreSQL 15+ (e.g. AWS RDS or GCP Cloud SQL) with Multi-AZ deployment enabled.
- [ ] **Row-Level Locking**: Ensure PostgreSQL dialect is active so `SELECT ... FOR UPDATE` row locks are natively enforced during slot bookings:
  ```python
  # Row lock enforced in backend/app/routers/bookings.py
  if db.bind.dialect.name != "sqlite":
      slot = query.with_for_update().first()
  ```
- [ ] **Alembic Migrations**: Run `alembic upgrade head` during deployment pipelines before new app instances start serving traffic.
- [ ] **DB Connection Pooling**: Set SQLAlchemy pool size (e.g., `pool_size=20, max_overflow=10`) matching container worker count.

---

## 3. Real-Time WebSocket Infrastructure & Queue State Sync
- [ ] **WebSocket Scalability**: Deploy Redis pub/sub or NGINX sticky sessions when scaling FastAPI horizontally across multiple nodes.
- [ ] **Token Authentication**: Enforce JWT auth handshake on WebSocket connects (`ws://domain/ws/centre/{centre_id}?token=JWT_TOKEN`).
- [ ] **REST Fallback Sync**: Mobile clients must poll `GET /queue/resync/{centre_id}` upon network drops or WebSocket disconnections.

---

## 4. AI Prediction Model Governance
- [ ] **Hybrid Model Pipeline**: RandomForest estimator blended with deterministic queue math (`blend_weight_model = 0.7`).
- [ ] **Retraining Schedule**: Schedule automated weekly retraining (`python ml_service/train.py`) using newly recorded completed `QueueEntry.actual_wait_minutes`.
- [ ] **Accuracy Monitoring**: Monitor `GET /admin/analytics/predicted-vs-actual` MAE and percentage within ±15 minutes threshold.

---

## 5. Notification Channel Redundancy
- [ ] **Dual-Channel Isolation**: FCM Push notifications and Indian SMS Provider calls are strictly decoupled using independent try/except blocks so failure in one channel never blocks the other.
- [ ] **Retry Strategy**: Implement Celery or Redis Queue for background retries with exponential backoff on transient SMS gateway timeouts.

---

## 6. Security & Audit Logging
- [ ] **Rate Limiting**: Enforce OTP verification rate limits (`5 attempts / 10 minutes / phone_number`).
- [ ] **Role-Based Access Control (RBAC)**: All sensitive endpoints enforce `RequireRole(["ADMIN", "SUPER_ADMIN"])`, `RequireRole(["FARMER"])`, or `RequireRole(["CENTRE_STAFF", "PACS_OPERATOR"])`.
- [ ] **Audit Trail**: Operational actions (centre pause/resume, quality rejection, collection forwarding) must write immutable audit records to `AuditLog` table.

---

## 7. Health Checks & Monitoring
- [ ] **Health Endpoint**: Configure Kubernetes / ALB liveness probe targeting `GET /health` (returns DB connection status).
- [ ] **Log Aggregation**: Route structured logs to CloudWatch / Datadog.
