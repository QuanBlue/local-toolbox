# OmniRoute (Omni)

[OmniRoute](https://github.com/diegosouzapw/OmniRoute) is an open-source AI gateway designed to act as an OpenAI-compatible endpoint, built on the foundations of 9Router. It routes requests intelligently across multiple providers and manages rate limits using Redis.

## Getting Started

Prerequisites: Docker Desktop running, with Docker Compose v2 or newer.

1. Copy the example environment file:
   ```bash
   cp .env.example .env
   ```

2. Edit `.env` and replace the secret/password placeholders. You can generate a random value in your terminal using:
   ```bash
   openssl rand -hex 16
   ```

3. Build and start the services. Since there is no official pre-built image, Docker will automatically download the source code from GitHub and build it locally. This might take a few minutes the first time:
   ```bash
   docker compose up -d --build
   ```

4. Open the dashboard at <http://localhost:20130>.

## Operations

- **Follow logs:**
  ```bash
  docker compose logs -f
  ```
- **Stop without erasing state:**
  ```bash
  docker compose down
  ```

> Note: OmniRoute state is stored in `data/` and Redis data in `redis-data/`. Both are excluded from Git.
