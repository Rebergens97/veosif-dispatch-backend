# Canonical Project Root

**This directory is the canonical Fleetbase project root for local development and customization.**

- Use this path for all commands: `docker compose`, `./scripts/local-start.sh`, and editing `api/`, `console/`, `docker/`, `scripts/`.
- **Do not** use the nested `fleetbase/` folder as your project root. That directory is a duplicate tree; see `fleetbase/DO_NOT_USE_README.txt`.

When in doubt, run Docker and scripts from **this** directory (the one that contains `api/`, `console/`, `docker-compose.yml`, and the `fleetbase/` subfolder).
