# 9Router

[9Router](https://github.com/decolua/9router) is an OpenAI-compatible endpoint router. This setup uses the pre-built image from Docker Hub.

## Start 9Router

Prerequisites: Docker Desktop running, with Docker Compose v2 or newer.

```bash
cp .env.example .env
```

Edit `.env` and replace all four secret/password placeholders. Generate a
random value in your terminal when needed:

```bash
openssl rand -hex 16
```

Then start the service:

```bash
docker compose up -d
```

Open the dashboard at <http://localhost:20128/dashboard>. The OpenAI-compatible
endpoint is `http://localhost:20128/v1`.

## Headroom (Token Saver: compress context)

Headroom runs as a second container (defined inline in `docker-compose.yml`)
and starts together with 9Router. After `docker compose up -d --build`, open the dashboard →
Endpoint → Token Saver → Headroom, set the URL to `http://headroom:8787`, and
turn the toggle on. If Headroom is down, 9Router sends the original request.

## Operations

```bash
# Follow logs
docker compose logs -f 9router

# Stop without erasing providers, settings, or SQLite data
docker compose down

# Update to latest image
docker compose pull
docker compose up -d
```

Persistent 9Router state is stored in `data/` and excluded from Git.
