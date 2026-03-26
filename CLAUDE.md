# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Docker-based sandbox for running Claude Code in an isolated container. The host system is protected — only the current project directory and `~/.claude` config are mounted. The container image is based on Playwright (Chromium-included) and ships Node.js 22, Python 3, FFmpeg, and common CLI tools.

## Architecture

- **Dockerfile** — Builds the `claudez` image on top of `mcr.microsoft.com/playwright`. Installs Claude Code globally via npm, adds system packages, configures passwordless sudo and git safe directories.
- **entrypoint.sh** — Runs as root, detects the UID:GID of the mounted working directory via `stat`, ensures config dirs exist with correct ownership, then drops privileges with `gosu` to run `claude` as the host user.
- **install.sh** — Builds the Docker image, creates `~/.claude` config dirs, and injects a `claudez` shell function into bashrc/zshrc/fish config. The function runs `docker run` with the correct volume mounts and env vars. Re-running install.sh replaces an existing function definition.
- **rebuild.sh** — Rebuilds the image with `--no-cache`.
- **uninstall.sh** — Removes the shell function from all detected shell configs and deletes the Docker image.

## Key Design Decisions

- Container runs with `--rm` so packages installed during a session are ephemeral.
- `CLAUDE_CODE_SKIP_PERMISSIONS=1` is set to enable `--dangerously-skip-permissions` by default.
- `--add-host host.docker.internal:host-gateway` allows the container to reach host-exposed services (databases, APIs).
- User identity is derived from the mounted directory's ownership (`stat -c '%u:%g'`), not from env vars, ensuring correct file permissions on created files.

## Commands

```bash
# First-time install (builds image + adds shell function)
./install.sh

# Rebuild image without cache (after Dockerfile changes)
./rebuild.sh

# Uninstall (removes shell function + Docker image)
./uninstall.sh

# Use (from any project directory, after install)
claudez            # new session
claudez --resume   # resume previous session
```
