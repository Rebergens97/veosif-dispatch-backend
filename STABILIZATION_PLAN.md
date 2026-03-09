# Fleetbase Stabilization Plan (Pre–VEOSIF Dispatch)

This plan applies **only minimum safe fixes** to make local Docker development reliable. No business logic, multi-tenant, or VEOSIF-specific changes.

---

## Goals

1. Resolve duplicate repository tree and define the single canonical project root.
2. Ensure `api/.env` exists with values required for local Docker.
3. Fix or remove invalid Docker healthchecks (e.g. `queue:status`).
4. Make queue and application wait for database (and cache) to be healthy before starting.
5. Provide a documented, repeatable local startup sequence.

---

## Priority Order and Actions

| # | Item | Action |
|---|------|--------|
| 1 | Duplicate tree | Document canonical root at repo root; add notice inside `fleetbase/` so it is not used as project root. |
| 2 | api/.env | Create from `api/.env.example` with APP_KEY, DB_DATABASE=fleetbase, APP_NAME=Fleetbase, and Docker-friendly defaults. |
| 3 | Healthchecks | Replace queue healthcheck `queue:status` (not in Laravel) with `php artisan --version` so the container is marked healthy when the app boots. |
| 4 | Startup order | Add `depends_on` with `condition: service_healthy` for database and cache on queue and application. |
| 5 | Startup sequence | Add `docker-compose.override.yml` from example (CORS + socket origins) and `scripts/local-start.sh` that runs `up -d`, waits for DB, then runs deploy. Document validation checklist. |

---

## Files Changed (Summary)

- **Created:** `STABILIZATION_PLAN.md` (this file)
- **Created:** `PROJECT_ROOT.md` (canonical root notice)
- **Created:** `fleetbase/DO_NOT_USE_README.txt` (do not use nested tree)
- **Created:** `api/.env` (from .env.example, Docker-ready)
- **Modified:** `docker-compose.yml` (queue healthcheck + depends_on conditions)
- **Created:** `docker-compose.override.yml` (local dev CORS + socket)
- **Created:** `scripts/local-start.sh` (reliable local startup)
- **Created:** `STABILIZATION_VALIDATION.md` (validation checklist)

---

## Out of Scope (Not Done)

- Multi-tenant or VEOSIF features
- Business logic changes
- Submodule initialization
- Changing Fleetbase branding or product behavior
