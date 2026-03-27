# Claudez

*The Phantom Zone for Claude Code.*

Run Claude Code in an isolated Docker container. Your host system stays safe — Claude can only access the current project directory.

## What's included

- Ubuntu 24.04 base with Node.js 22, Python 3, FFmpeg, git, curl, jq
- Chromium via Playwright (for browser automation / MCP)
- Runs as your user (correct file ownership)
- Passwordless sudo inside container (Claude can `apt install` on the fly)
- `--dangerously-skip-permissions` enabled by default

## Install

```bash
git clone <repo-url> && cd claudez
chmod +x install.sh
./install.sh
```

This builds the Docker image and adds the `claudez` shell function to your bashrc/zshrc/fish config.

### Playwright MCP (optional)

The image ships with Playwright and Chromium. To enable browser automation via MCP:

```bash
claude mcp add -s user playwright -- npx @playwright/mcp@latest --headless --no-sandbox
```

To rebuild after changes (e.g. updating the Dockerfile):

```bash
./install.sh
```

## Usage

```bash
cd ~/projects/myapp
claudez
```

Resume a previous session:

```bash
claudez --resume
```

Mount additional directories (read/write):

```bash
claudez -v ~/projects/other-repo
claudez -v ~/projects/other-repo -v ~/data/shared
```

Connect to a Docker network (e.g. to reach project databases):

```bash
claudez -n myapp_default
```

Use a custom Docker image:

```bash
claudez --image claudez-rust
```

Or set a per-project default by creating a `.claudez-image` file:

```bash
echo "claudez-rust" > .claudez-image
claudez   # automatically uses claudez-rust
```

Priority: `--image` flag > `.claudez-image` file > default `claudez`.

Combine flags:

```bash
claudez -v ~/projects/other-repo -n myapp_default --resume
claudez --image claudez-go --model opus
```

## What's isolated

| Resource | Access |
|---|---|
| Project directory | Read/Write (mounted) |
| ~/.claude config | Read/Write (mounted, for auth & sessions) |
| Rest of filesystem | No access |
| Windows drives | No access |
| Docker socket | No access |
| Network | Full (needed for Claude API) |

## Connecting to project databases

If your project runs via docker-compose, connect the sandbox to the same network with `-n`:

```bash
claudez -n myapp_default
```

Find your network name with `docker network ls`.

## Backup

Back up Claude config directories (`~/.claude`, `~/.claude.json`, `~/.config/claude-code`):

```bash
./backup.sh              # saves to ~/claude-backups/
./backup.sh /path/to/dir # custom backup location
```

Restore from a backup:

```bash
tar -xzf ~/claude-backups/claude_backup_20260326_120000.tar.gz -C /
```

## Custom images

The default `claudez` image includes Node.js, Python, and Playwright. For projects that need different toolchains, build a custom image.

### Extending the default image

```dockerfile
FROM claudez
RUN apt-get update && apt-get install -y rustc cargo && rm -rf /var/lib/apt/lists/*
```

```bash
docker build -t claudez-rust -f Dockerfile.rust .
```

### Building from scratch

Custom images must include `gosu`, `git`, and the `entrypoint.sh` script. Minimal example:

```dockerfile
FROM ubuntu:24.04
RUN apt-get update && apt-get install -y curl gnupg git gosu sudo \
    && curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
    && apt-get install -y nodejs \
    && npm install -g @anthropic-ai/claude-code \
    && rm -rf /var/lib/apt/lists/*
RUN git config --global --add safe.directory '*'
RUN echo "ALL ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/claude
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
```

### Rebuilding custom images

```bash
./rebuild.sh claudez-rust Dockerfile.rust
```

## Limitations

- Packages installed by Claude during a session are lost on exit (`--rm`). Claude will reinstall if needed on resume.
- File-heavy operations on `/mnt/c/...` paths (Windows filesystem) are slow. Prefer WSL ext4 paths (`/home/...`).
- Container shares the host network — Claude can make outbound requests.
- Docker isolation is not VM-level. Sufficient for sandboxing Claude, not for running untrusted malware.

## Uninstall

Remove the `claudez` function from your shell config (`~/.bashrc`, `~/.zshrc`, or `~/.config/fish/functions/claudez.fish`), then:

```bash
docker rmi claudez
```
