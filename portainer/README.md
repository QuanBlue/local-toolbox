# Portainer

A powerful web-based UI that allows you to easily manage your Docker environments, including Containers, Images, Networks, and Volumes.

## Getting Started

1. Ensure Docker is running.
2. From the `portainer` directory, run the following command:
   ```bash
   docker compose up -d
   ```
3. Access the web interface at: `http://localhost:9000`

## Operations

- **Follow logs:**
  ```bash
  docker compose logs -f portainer
  ```
- **Stop without erasing data:**
  ```bash
  docker compose down
  ```

> Portainer's data is persisted in the `data/` folder within this directory. Your passwords and configuration will not be lost when you restart the container.
