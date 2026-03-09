# Fleetbase Repository Audit Report

**Audit date:** March 8, 2025  
**Purpose:** Pre-customization audit for VEOSIF Dispatch  
**Scope:** Full repository inspection (read-only, no code changes)

---

## Executive Summary

The Fleetbase project is a **modular logistics/supply chain OS** with a Laravel API, Ember.js console (frontend), and Docker-based deployment. The repository is **generally consistent** but has several issues that can cause failed or flaky local startup: **submodules are not initialized** (packages and docs are empty), **Docker Compose relies on a pre-built image** (`fleetbase/fleetbase-api:latest`) and a **missing `api/.env`** unless created by the install script, and the **queue healthcheck uses a non-standard Artisan command** that may not exist. There is also a **duplicate tree** (`fleetbase/` inside the repo) that can cause confusion. Fixing submodules, clarifying which root to use, and addressing the queue healthcheck and startup order will make the project **safe to customize** for VEOSIF Dispatch after the recommended fixes.

---

## 1. Repository Structure Review

### 1.1 Top-level layout

| Path | Purpose |
|------|--------|
| `api/` | Laravel application (backend) |
| `console/` | Ember.js application (frontend) |
| `docker/` | Dockerfiles and HTTP/DB config |
| `packages/` | Git submodules (Fleetbase extensions/engines) |
| `docs/` | Git submodule (documentation) |
| `scripts/` | `docker-install.sh` and helpers |
| `infra/` | Helm charts |
| `workflows/` | CI/CD (e.g. GitLab) |
| `builds/` | OS-specific build configs |

Required files present at repo root: `README.md`, `docker-compose.yml`, `.gitmodules`, `.gitignore`, `docker-compose.override.yml.example`, `Caddyfile`, `docker-bake.hcl`, `create-erd.sh`, `database.mmd`, and various `.github/workflows/*.yml`.

### 1.2 Duplicate tree: `fleetbase/`

- A **full duplicate** of the repository exists under **`fleetbase/`** (including `api/`, `console/`, `docker/`, `packages/`, `scripts/`, `.github/`, etc.).
- `fleetbase/` contains its own **`.git`** directory, so it behaves as a nested clone.
- **Risk:** Unclear which root is “canonical.” Docker Compose at the **parent root** references `./api`, `./console`, `./docker`; those paths exist at **both** roots.
- **Recommendation:** Treat the **parent directory** (the one containing the `fleetbase` folder) as the single source of truth for local development and remove or clearly document the nested `fleetbase/` clone to avoid editing the wrong tree.

### 1.3 Submodules

- **`.gitmodules`** (same at root and inside `fleetbase/`) defines:
  - **Packages:** `packages/fleetops`, `packages/storefront`, `packages/pallet`, `packages/core-api`, `packages/ember-core`, `packages/ember-ui`, `packages/iam-engine`, `packages/dev-engine`, `packages/fleetbase-extensions-indexer`, `packages/fleetops-data`, `packages/registry-bridge`, `packages/ledger`
  - **Docs:** `docs`
- **Current state:** The workspace is **not a git repo** at the parent level (“Is directory a git repo: No”). Submodule directories under `packages/` and `docs/` are **present but empty** (only placeholder dirs; no checked-out content).
- **Impact:** Backend and frontend **do not rely on local package paths** for normal runs: API uses Composer packages from **https://registry.fleetbase.io**; console uses **npm/pnpm** packages (e.g. `@fleetbase/ember-core`, `@fleetbase/fleetops-engine`) from the registry. So the app can run without initializing submodules, but **development of those packages** or **building from source** requires submodules to be initialized and updated.

### 1.4 Missing / suspicious files

- **`api/.env`** is **missing** in the tree. It is required by Docker Compose (`./api/.env` mounted into the application container). The install script generates `APP_KEY` and writes `docker-compose.override.yml` but does not create `api/.env`; that file must be created from `api/.env.example` (or by the installer if it’s supposed to—worth confirming).
- **`docker/database/`** contains only `.gitkeep` and an empty `mysql/` dir; no SQL init scripts. DB is created by the application via `php artisan mysql:createdb` in `deploy.sh`. This is by design but means **first-run DB setup is entirely inside the application container**.

---

## 2. Docker Review

### 2.1 Services in `docker-compose.yml`

| Service | Image / build | Ports | Purpose |
|--------|----------------|------|--------|
| **cache** | `redis:4-alpine` | (internal) | Redis for cache and queues |
| **database** | `mysql:8.0-oracle` | 3306 | MySQL 8, DB name `fleetbase` |
| **socket** | `socketcluster/socketcluster:v17.4.0` | 38000→8000 | WebSocket server |
| **scheduler** | `fleetbase/fleetbase-api:latest` | — | Cron (go-crond + crontab) |
| **queue** | `fleetbase/fleetbase-api:latest` | — | `php artisan queue:work` |
| **console** | Build from `./console` | 4200 | Ember app served by nginx |
| **application** | `fleetbase/fleetbase-api:latest` | (via httpd) | Laravel API (Octane/FrankenPHP) |
| **httpd** | Build from `./` + `docker/httpd/Dockerfile` | 8000→80 | Nginx reverse proxy to application |

### 2.2 Port usage

- **3306** – MySQL (host)
- **38000** – SocketCluster (host)
- **4200** – Console (host)
- **8000** – API (via httpd)

No duplicate port mappings in this file. If other stacks run on the same host, ensure 3306, 38000, 4200, and 8000 are free.

### 2.3 Service dependency and health

- **application** `depends_on`: database, cache, **queue**. It does **not** depend on **socket** or **scheduler**. So real-time features can fail if `socket` is not up; scheduled tasks won’t run if `scheduler` is not up.
- **queue** healthcheck: `php artisan queue:status`. **Laravel does not ship `queue:status`.** If this command is not provided by a Fleetbase package (e.g. core-api), the queue container will repeatedly be marked **unhealthy** and may be restarted by the orchestrator. This is a **real risk** and should be verified or replaced (e.g. with `queue:monitor` or a custom command).
- **database** and **cache** have healthchecks; Compose does not use `depends_on: condition: service_healthy`, so **queue** and **application** can start before DB is actually ready.

### 2.4 Alignment with repo structure

- **httpd** build context is `.`; Dockerfile copies `docker/httpd/vhost.conf` and `api/public/`. So it expects to be run from the **repo root** where `api/` and `docker/` exist. ✅
- **console** build context is `./console`; Dockerfile and `fleetbase.config.json` path are correct. ✅
- **application** and **queue** use the pre-built image `fleetbase/fleetbase-api:latest` and mount `./api/.env`. No local API build is used; **api/.env must exist** and be valid.

### 2.5 Services required for local development

- **Minimum:** database, cache, application, httpd, console (to use API + UI).
- **Recommended:** + queue (for async jobs), + scheduler (for cron), + socket (for real-time). Without socket, set `BROADCAST_DRIVER=log` or equivalent to avoid runtime errors.

---

## 3. Backend (Laravel/PHP) Review

### 3.1 Structure

- Standard Laravel layout under `api/`: `app/`, `config/`, `database/` (migrations, seeders, factories), `bootstrap/`, `public/`, `routes/`, `storage/`, `tests/`. No `bootstrap/providers.php` (Laravel 10 uses `config/app.php` / package discovery).

### 3.2 Composer and registry

- **composer.json** requires PHP `>=8.0 <=8.2.30`, Laravel `^10.0`, and Fleetbase packages:
  - `fleetbase/core-api`, `fleetbase/fleetops-api`, `fleetbase/registry-bridge`, `fleetbase/storefront-api`
- **Repository:** `https://registry.fleetbase.io`. Composer install/update will pull these from the registry (requires auth for private packages).
- **composer.lock** is present (~18.5k lines). **`api/vendor/` is not present** in the tree—so either dependencies are installed in CI/image build, or they must be installed locally for non-Docker runs.

### 3.3 Config and env

- **api/.env.example** is generic Laravel (e.g. `DB_DATABASE=laravel`). Docker uses `DATABASE_URL=mysql://root@database/fleetbase` and `MYSQL_DATABASE=fleetbase`. For **local non-Docker** runs, `.env` should set `DB_DATABASE=fleetbase` (and match DB host/port).
- Config files reference Fleetbase (e.g. `config/app.php` `APP_NAME` default `Fleetbase`, `config/cors.php` uses `Fleetbase\Support\Utils`, `config/octane.php` uses `Utils`). These come from the `fleetbase/core-api` (or similar) package; no local path references to `packages/` in the inspected PHP.

### 3.4 Deploy script and Artisan commands

- **api/deploy.sh** runs: `mysql:createdb`, `migrate`, `sandbox:migrate`, `fleetbase:seed`, `fleetbase:create-permissions`, `queue:restart`, `schedule-monitor:sync`, cache/route clear and cache, `registry:init`, (optional octane reload). All of these are **custom or package commands** (not core Laravel); they depend on Fleetbase packages being installed.

### 3.5 Migrations and seeders

- **database/seeders/DatabaseSeeder.php** is default Laravel (empty run). Seeding is done via **`fleetbase:seed`** from a package.
- Migrations live in `api/database/migrations/`; sandbox DB uses **`sandbox:migrate`**.

### 3.6 Broken references / invalid paths

- No hardcoded references to `packages/` or `fleetbase/` in the PHP files under `api/` that were checked. Autoload and config assume packages are in `vendor/` after Composer install.
- **Fleetbase\Support\Utils** in config implies **core-api** (or equivalent) must be installed or config will fail at runtime.

---

## 4. Frontend (Console) Review

### 4.1 Stack

- **Ember.js** app (`@fleetbase/console`), Ember Octane, node `>= 18`, pnpm. Build: `ember build`; serve: `ember serve` (dev) or nginx (Docker).

### 4.2 API and socket configuration

- **config/environment.js** reads: `API_HOST`, `API_NAMESPACE` (default `int/v1`), `SOCKETCLUSTER_*`, `OSRM_HOST`, etc., via `getenv()` (e.g. from `.env.development` / `.env.production` in `console/environments/`).
- **fleetbase.config.json** (root of console) provides runtime overrides; in Docker it’s mounted into the built app at `/usr/share/nginx/html/fleetbase.config.json`. Default in repo: `"API_HOST": "http://localhost:8000"`. So the **built console** talks to the API at the host and port exposed by httpd (8000).

### 4.3 Dependencies

- **package.json** depends on **@fleetbase/** packages: dev-engine, ember-core, ember-ui, fleetops-data, fleetops-engine, iam-engine, registry-bridge-engine, storefront-engine, plus fleetbase-extensions-indexer. These are pulled from the **Fleetbase npm registry** (or public npm if published). No local `packages/` path in package.json; **ember-addon** path is only `lib/fleetbase-extensions-generator` (in-repo).

### 4.4 Build and assets

- **ember-cli-build.js** includes `fleetbase.config.json` in the build (unless `DISABLE_RUNTIME_CONFIG`); fingerprint excludes `fleetbase.config.json`, `extensions.json`, etc. **nginx.conf** (serve stage) serves `/fleetbase.config.json` with no-cache headers. Aligns with Docker volume mount of `fleetbase.config.json`.

### 4.5 Config mismatches / issues

- **API host:** Console expects API at `API_HOST` (e.g. `http://localhost:8000`). Docker Compose and install script set this via `fleetbase.config.json` and override. If you run console in dev with `ember serve` and API in Docker, `localhost:8000` is correct; if API is elsewhere, update `fleetbase.config.json` or env.
- **Socket:** Default port 38000 and host from config; override example sets `SOCKETCLUSTER_OPTIONS` for origins. Without override, SocketCluster may reject connections from the browser; use `docker-compose.override.yml` (from example) for local dev.
- No **.npmrc** in console in the tree; registry auth for `@fleetbase` would be required if those packages are private.

---

## 5. Extensions and Packages (Submodules) Review

### 5.1 Listed in .gitmodules

| Submodule | Role (from naming and usage) |
|-----------|-------------------------------|
| **packages/core-api** | Core API and support (e.g. `Fleetbase\Support\Utils`, Laravel integration) |
| **packages/fleetops** | Fleet ops engine (API + Ember engine) |
| **packages/storefront** | Storefront feature set |
| **packages/pallet** | Pallet/inventory feature set |
| **packages/ember-core** | Shared Ember core (used by console) |
| **packages/ember-ui** | Shared UI components |
| **packages/iam-engine** | IAM engine |
| **packages/dev-engine** | Dev tooling |
| **packages/fleetbase-extensions-indexer** | Extensions indexer |
| **packages/fleetops-data** | Fleet ops data layer |
| **packages/registry-bridge** | Registry bridge (API + engine) |
| **packages/ledger** | Ledger/billing |

### 5.2 State and usage

- All package and **docs** submodule dirs are **empty** (not checked out). The API and console **do not** reference these paths for normal run; they use **Composer** and **npm** packages from **registry.fleetbase.io** and npm.
- For **developing** these packages or building everything from source, you must:
  - Have a git repo and run `git submodule update --init --recursive`.
  - Possibly build and publish packages to a local or private registry, or link them locally.

### 5.3 Outdated / disconnected / misconfigured

- **Outdated:** Not assessed (no package content checked out).
- **Disconnected:** Submodules are not initialized; any script or doc that assumes `packages/*` or `docs/` has content will see empty or missing files.
- **Misconfigured:** `.gitmodules` uses `git@github.com:fleetbase/...`; cloning requires SSH access to GitHub. No alternate HTTPS or path config in the audited files.

---

## 6. Startup Flow Review

### 6.1 Intended order (from README and scripts)

1. **Prerequisites:** Docker + Docker Compose, Node (for CLI). Optional: `@fleetbase/cli` or `./scripts/docker-install.sh`.
2. **Configure:** Create `docker-compose.override.yml` (install script does this), set **api/.env** (from `.env.example` at minimum: `APP_KEY`, `DB_*` if not using Docker DB URL). For console, **fleetbase.config.json** (and optionally `console/environments/.env.*`) set API and socket URLs.
3. **Start:** `docker compose up -d` (or after running `docker-install.sh`).
4. **Wait for DB:** Install script waits for database healthy (or mysqladmin ping).
5. **Deploy:** `docker compose exec application bash -c "./deploy.sh"` (creates DB, migrations, seed, permissions, registry init, etc.).

### 6.2 Why the project sometimes starts with errors

- **Missing api/.env:** Compose mounts `./api/.env`. If it’s missing, the application container may fail or use wrong config. The install script does not create `api/.env`; only override and console config.
- **Queue healthcheck:** `php artisan queue:status` can fail if that command doesn’t exist, marking the queue service unhealthy and causing restarts or dependency issues.
- **Startup order:** `application` depends on `queue`, but Compose does not wait for database/cache to be healthy before starting queue/application. So **queue:work** and the app can start before MySQL is ready, causing connection errors and retries.
- **Pre-built image:** If `fleetbase/fleetbase-api:latest` is not pulled or is outdated, or if the image expects a different env/layout, startup can fail.
- **Socket not in depends_on:** Console and API may try to use SocketCluster before the socket service is up; override with correct `SOCKETCLUSTER_OPTIONS` and ensure socket is started.

### 6.3 Fragile areas

- **First run:** No `.env` in api, no override file, and no ran deploy script → API and queue will fail or behave incorrectly.
- **Deploy script:** Assumes all Artisan commands exist (Fleetbase packages installed in the image). If the image is minimal or broken, `deploy.sh` will fail.
- **Single point of truth:** Two roots (parent and `fleetbase/`) can lead to editing the wrong copy; Docker runs from parent root.

---

## 7. Risks and Recommended Fixes

### 7.1 Top technical risks before customization

1. **Submodules not initialized** – Empty `packages/` and `docs/`; any workflow or doc that assumes they’re populated will break; package development from source is not possible until fixed.
2. **Queue healthcheck** – `queue:status` may not exist → queue service unhealthy; verify and replace or remove healthcheck.
3. **Missing api/.env** – Application container expects it; first-time and doc-driven setups will fail unless `.env` is created from example and APP_KEY/DB set.
4. **Duplicate repo root (fleetbase/)** – Confusion and edits in the wrong tree; possible drift between the two copies.
5. **No depends_on health conditions** – Queue and application can start before database/cache are ready; add `condition: service_healthy` where appropriate or document and handle retries.
6. **External registries** – API and console depend on **registry.fleetbase.io** and npm; network or auth issues will block installs and runs.
7. **Socket and scheduler not required** – Real-time and cron may be broken if those services aren’t running or not configured; document and optionally add depends_on for socket for full functionality.

### 7.2 Recommended fixes before building VEOSIF Dispatch

1. **Define canonical root:** Use the **parent directory** (the one that contains `fleetbase/`) as the only root; remove the nested `fleetbase/` clone or document it as “mirror / do not edit.”
2. **Document and automate api/.env:** Add a step in README or install script: copy `api/.env.example` to `api/.env`, set `APP_KEY` (e.g. `php artisan key:generate --show`) and `DB_DATABASE=fleetbase` for local runs; ensure Docker override or script doesn’t overwrite needed values.
3. **Fix or remove queue healthcheck:** Confirm whether a Fleetbase package registers `queue:status`; if not, switch to `queue:monitor redis:default` (or equivalent) or remove the healthcheck and use a simple `php -v` or `artisan --version` until a proper check exists.
4. **Harden startup order:** Add `depends_on` with `condition: service_healthy` for database (and optionally cache) for **queue** and **application** so they start only after DB is ready.
5. **Initialize submodules when needed:** If you need packages or docs, run `git submodule update --init --recursive` and document it; otherwise state clearly that the app runs from registry packages and submodules are optional.
6. **Create docker-compose.override.yml for dev:** Ensure developers either run the install script or copy `docker-compose.override.yml.example` to `docker-compose.override.yml` and set at least `CONSOLE_HOST` and socket `SOCKETCLUSTER_OPTIONS` for localhost.

---

## 8. “Safe to Begin Customization?” Verdict

**Conditionally yes.**

- **Safe to customize** once:
  - You use a **single canonical root** (parent directory) and avoid editing inside `fleetbase/` unless you explicitly treat it as the clone.
  - **api/.env** exists and is correct for your environment (Docker or local).
  - You’ve verified **queue** healthcheck (fix or remove as above) and are aware that **socket** and **scheduler** are optional but needed for full behavior.
  - You accept dependency on **registry.fleetbase.io** (and npm) for API and console dependencies; submodules are optional unless you develop those packages.

- **Recommended before heavy VEOSIF Dispatch work:** Apply the fixes in §7.2 (canonical root, .env setup, queue healthcheck, startup order, override file). Then run a full **docker compose up**, run **deploy.sh**, and confirm console and API respond and (if needed) socket and scheduler work. After that, the codebase is in a known-good state for customization.

---

*End of audit report. No code or config was modified during this inspection.*
