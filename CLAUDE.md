# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Docker-based sandbox for running Claude Code in an isolated container. The host system is protected — only the current project directory and `~/.claude` config are mounted. The container image is based on Playwright (Chromium-included) and ships Node.js 22, Python 3, FFmpeg, and common CLI tools.

## Architecture

- **Dockerfile** — Builds the default `claudez` image on top of `ubuntu:24.04`. Installs Claude Code globally via npm, adds system packages (Node.js, Python, Playwright/Chromium), configures passwordless sudo and git safe directories. Custom images can extend this with `FROM claudez` or build from scratch (must include `gosu`, `git`, and `entrypoint.sh`).
- **entrypoint.sh** — Runs as root, detects the UID:GID of the mounted working directory via `stat`, ensures config dirs exist with correct ownership, then drops privileges with `gosu` to run `claude` as the host user.
- **install.sh** — Builds the Docker image, creates `~/.claude` config dirs, and injects a `claudez` shell function into bashrc/zshrc/fish config. The function runs `docker run` with the correct volume mounts and env vars. Re-running install.sh replaces an existing function definition.
- **rebuild.sh** — Rebuilds an image with `--no-cache`. Accepts optional `<image-name>` and `<dockerfile>` arguments.
- **uninstall.sh** — Removes the shell function from all detected shell configs and deletes the Docker image.

## Key Design Decisions

- Container runs with `--rm` so packages installed during a session are ephemeral.
- `CLAUDE_CODE_SKIP_PERMISSIONS=1` is set to enable `--dangerously-skip-permissions` by default.
- `--add-host host.docker.internal:host-gateway` allows the container to reach host-exposed services (databases, APIs).
- User identity is derived from the mounted directory's ownership (`stat -c '%u:%g'`), not from env vars, ensuring correct file permissions on created files.
- `--docker` flag enables Docker Compose by mounting the host's Docker socket (`/var/run/docker.sock`). The entrypoint detects the socket's GID and adds the container user to a matching group. Opt-in because socket access grants root-equivalent host access.
- Playwright MCP server (`@playwright/mcp`) is baked into the image. Enable with `claude mcp add -s user playwright -- npx @playwright/mcp@latest --headless --no-sandbox`. `--no-sandbox` is required because Chrome can't create namespaces inside Docker. MCP config lives in `~/.claude.json`, not `settings.json`.

## Custom Images

Per-project config lives in a `.claudez` file (key=value format). Supported keys: `image`, `docker`. CLI flags override file values.

The `claudez` shell function resolves the image to use in this order:
1. `--image <name>` flag (highest priority)
2. `image=` in `.claudez` file
3. Default `claudez` image

Custom images must include `gosu`, `git`, and `entrypoint.sh`. Easiest approach: `FROM claudez` then add tooling.

## Commands

```bash
# First-time install (builds image + adds shell function)
./install.sh

# Rebuild image without cache (after Dockerfile changes)
./rebuild.sh                              # default image
./rebuild.sh claudez-rust Dockerfile.rust  # custom image

# Uninstall (removes shell function + Docker image)
./uninstall.sh

# Use (from any project directory, after install)
claudez                        # new session
claudez --resume               # resume previous session
claudez --image claudez-rust   # use custom image
```
