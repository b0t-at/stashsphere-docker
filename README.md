# stashsphere-docker

End-to-end Docker setup for [StashSphere](https://github.com/stashsphere/stashsphere) with:

- a reproducible Docker image build
- a ready-to-run `docker-compose.yml` that uses a hosted image
- auto-generated default config on first start (optional but enabled by default)
- GitHub Actions workflow to build and publish a public image to GHCR

## What this repository gives you

1. **Reliable Docker build**
	 - Builds the backend binary from upstream StashSphere source (`STASHSPHERE_REF`)
	 - Multi-stage image for a lean runtime
	 - Container entrypoint that can auto-generate config and run migrations

2. **Reliable GitHub Action (public image hosting)**
	 - Builds on PRs
	 - Builds + pushes to **public GHCR** on `main` and `v*` tags
	 - No redeploy hooks, no post-build deployment triggers

3. **Runtime deployment with Traefik**
	 - Compose consumes a hosted image (`STASHSPHERE_IMAGE`)
	 - Runtime is driven by `.env` variables
	 - Traefik labels included (`entrypoints=https`, external network `proxy`)

4. **Config + improvements**
	 - Config bind mount via `./config:/config`
	 - Image store bind mounts via:
		 - `./data/image_store:/data/image_store`
		 - `./data/image_cache:/data/image_cache`
	 - If no config exists, a ready-to-edit default `config/stashsphere.yaml` is generated automatically

## Files

- `Dockerfile` – multi-stage build for StashSphere backend
- `docker/entrypoint.sh` – runtime bootstrap (default config + migration + serve)
- `docker/default-config.yaml` – template used for first-start config generation
- `docker-compose.yml` – Traefik-ready runtime stack for hosted image
- `.github/workflows/docker-image.yml` – CI build/publish to GHCR
- `.env.example` – env template for compose/runtime
- `config/stashsphere.yaml.example` – editable non-secret config example
- `config/secrets.yaml.example` – editable secret config example

## Quick start (local)

1. Review `.env` (already created with placeholders/defaults).
2. Ensure the Traefik network exists:
	 - `docker network create proxy`
3. Start the stack:
	 - `docker compose up -d`
4. Check logs:
	 - `docker compose logs -f stashsphere`

On first start, if `config/stashsphere.yaml` is missing and `STASHSPHERE_AUTO_CREATE_CONFIG=true`, the container creates it automatically.

## Config behavior

The entrypoint expects:

- main config: `/config/stashsphere.yaml` (configurable)
- optional secrets file: `/config/secrets.yaml`

At runtime:

- both files are passed as chained `--conf` values when present
- migrations run before `serve` when `STASHSPHERE_AUTO_MIGRATE=true`
- image paths default to `/data/image_store` and `/data/image_cache`

## Traefik integration

The service is configured with labels for:

- router name: `stashsphere`
- rule: `Host(${TRAEFIK_HOST})`
- entrypoint: `https`
- TLS: enabled
- certresolver: `${TRAEFIK_CERTRESOLVER}` (default `letsencrypt`)
- target service port: `8081`
- docker network: `proxy`

## GitHub Actions: required secrets and variables

Workflow file: `.github/workflows/docker-image.yml`

### Required secrets

- **None to add manually** for GHCR in the same repository.
	- The workflow uses `${{ secrets.GITHUB_TOKEN }}`.

### Required repository settings

- Actions permissions must allow package publishing (workflow already requests `packages: write`).
- Ensure the published GHCR package visibility is set to **public**.

### Optional repository variables

- `IMAGE_NAME` (default: `stashsphere`)
	- final image: `ghcr.io/<owner>/<IMAGE_NAME>`
- `STASHSPHERE_REF` (default: `main`)
	- upstream ref to build from (branch, tag, or commit)

## Notes

- This setup intentionally **does not** trigger any redeploys after image build.
- If you prefer split config/secrets, copy and edit:
	- `config/stashsphere.yaml.example` -> `config/stashsphere.yaml`
	- `config/secrets.yaml.example` -> `config/secrets.yaml`
- For production, set secure domains, SMTP, and a strong DB password.
