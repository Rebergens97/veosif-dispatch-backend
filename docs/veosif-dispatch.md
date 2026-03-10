# VEOSIF Dispatch — System Status and Protected Configuration

**Status:** Login working on server (104.131.20.188). Do not change protected configuration below.

---

## Current deployment

| URL | Service |
|-----|---------|
| http://104.131.20.188:8000 | API (Laravel + Fleetbase packages) |
| http://104.131.20.188:4200 | Console (Ember.js) |
| :38000 | SocketCluster (WebSockets) |

---

## Required environment variables (must stay correct)

These must be set in `docker-compose.override.yml` (or equivalent env for the application service) and in `api/.env` on the server. Changing any of these can break login immediately.

| Variable | Current value (server) | Why it matters |
|----------|----------------------|----------------|
| `APP_URL` | `http://104.131.20.188:8000` | Laravel app URL; Sanctum derives stateful domain from this |
| `SESSION_DOMAIN` | `104.131.20.188` | Session cookie domain; must match browser host or cookie is rejected |
| `CONSOLE_HOST` | `http://104.131.20.188:4200` | CORS allowed origin and Sanctum stateful domain for the console |
| `APP_KEY` | (set; do not change) | Laravel encryption key; changing it invalidates all sessions and tokens |
| `DB_DATABASE` | `fleetbase` | Must match MySQL database name in docker-compose |
| `BROADCAST_DRIVER` | `socketcluster` | Real-time events driver |

---

## Protected files — do NOT modify without explicit approval

### Backend (api/)

| File | Role |
|------|------|
| `api/.env` | Runtime env (APP_KEY, DB_*, APP_URL, SESSION_DOMAIN, CONSOLE_HOST) |
| `api/config/cors.php` | CORS allowed origins (uses CONSOLE_HOST + FRONTEND_HOSTS) |
| `api/config/session.php` | Session driver, lifetime, cookie domain |
| `api/config/sanctum.php` | Stateful domains (auto-derived from APP_URL + CONSOLE_HOST) |
| `api/config/auth.php` | Guards and providers |
| `api/app/Http/Middleware/Authenticate.php` | JSON "Unauthenticated." response |
| `api/app/Http/Kernel.php` | Global + route middleware groups |
| `api/app/Models/User.php` | User model (HasApiTokens) |
| `api/app/Providers/AuthServiceProvider.php` | Auth policy registration |

### Docker

| File | Role |
|------|------|
| `docker-compose.yml` | Service definitions, health conditions, env defaults |
| `docker-compose.override.yml` | Server-specific overrides (APP_KEY, CONSOLE_HOST, APP_URL, SESSION_DOMAIN) |
| `docker/httpd/` | nginx reverse proxy config |
| All Dockerfiles | Image build definitions |

### Console auth (do not change auth logic)

| File | Role |
|------|------|
| `console/app/adapters/application.js` | Re-exports @fleetbase/ember-core adapter |
| `console/app/controllers/auth/login.js` | Login controller (uses `authenticator:fleetbase`) |
| `console/app/controllers/auth/two-fa.js` | 2FA controller |
| `console/app/routes/console.js` | Auth guard for all console routes |
| `console/app/router.js` | Route structure + engine mounts (fleet-ops, iam, etc.) |

---

## What can break login

- Changing `SESSION_DOMAIN` to a value that does not match the browser's host (e.g. setting to `localhost` when accessing via IP).
- Removing or changing `CONSOLE_HOST` (breaks CORS allowed origins and Sanctum stateful domains).
- Changing `APP_KEY` (invalidates all sessions and tokens; everyone is logged out).
- Changing `allowed_origins` or `supports_credentials` in `api/config/cors.php`.
- Changing `stateful` in `api/config/sanctum.php` so the console origin is excluded.
- Changing session `domain` or `driver` in `api/config/session.php`.

---

## Safe changes (no approval needed)

- Docs and markdown files only.
- Frontend visible text (titles, translations, welcome messages) — see branding plan.
- Adding new documentation in `docs/`.
- Running `docker compose ps`, `docker compose logs`, and other read-only operations.

---

## Working sequence for fresh deploy on server

1. Set `APP_URL`, `SESSION_DOMAIN`, `CONSOLE_HOST` in `docker-compose.override.yml` (and optionally in `api/.env`).
2. Run `docker compose up -d` (or `./scripts/local-start.sh`).
3. Wait for DB healthy, then run `docker compose exec application bash -c "./deploy.sh"`.
4. Validate: see `STABILIZATION_VALIDATION.md`.
