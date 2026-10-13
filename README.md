# local-toolbox

A collection of self-hosted developer tools running on Docker Compose. Each tool is separated into its own folder with its own `docker-compose.yml` and `README.md` for independent management.

## Tools Overview

| Tool | Folder | Description | Guide |
|---|---|---|---|
| **9Router** | `9router/` | OpenAI-compatible endpoint router | [View details](./9router/README.md) |
| **OmniRoute** | `omni/` | Advanced AI gateway & router (with Redis) | [View details](./omni/README.md) |
| **Portainer** | `portainer/` | Web UI for managing Docker & Containers | [View details](./portainer/README.md) |
| **Tailscale** | `tailscale/` | Zero config VPN node and proxy | [View details](./tailscale/README.md) |

## General Usage
1. Navigate to the tool's folder you want to run (e.g., `cd 9router`).
2. Read the `README.md` file in that folder for configuration instructions (like setting up `.env`).
3. Run `docker compose up -d` to start the tool.

> Note: Data (state, databases) for each tool is stored within its respective `data/` folder to keep backups and migrations straightforward.
