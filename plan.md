# Claude Dev Sandbox – Complete Implementation Guide

*Generated: 2025-08-06 11:39:51*

---

## 0 · Vision & Context
This repository provides a **turn‑key workflow** for spinning up an isolated **Claude‑Code** development sandbox for _every_ Git work‑tree on your machine.  
Key goals agreed during design discussion:

| Decision | Value |
|----------|-------|
| Work‑tree parking lot | `~/worktrees/<repo>/<branch>` |
| Container engine | **Colima** (Docker‑compatible CLI) |
| Image base | `alpine:latest` + minimal runtime packages |
| Claude backend | Amazon **Bedrock** via `aws‑vault --server` running on the host |
| Container privilege | **root** (inside container) |
| Exec method | `docker exec -it` (no sshd) |
| Naming convention | `cc-<branch>` |
| Extensibility | `docker‑compose.yml` for DB sidecars etc. |
| Scripts | `cc-up`, `cc-chat`, `cc-stop`, `cc-clean`, `cc-awsvault` |
| Clean‑up | `cc-clean` removes work‑tree & container |
| Install/Removal | `install.sh`, `uninstall.sh` copy / delete toolkit in any repo |
| Config | `.ccenv` file (env‑vars) – everything overridable |

---

## 1 · Repository skeleton

```
claude-dev-sandbox/
├─ Dockerfile
├─ docker-compose.yml
├─ scripts/
│  ├─ _common.sh
│  ├─ cc-awsvault
│  ├─ cc-up
│  ├─ cc-chat
│  ├─ cc-stop
│  ├─ cc-clean
│  └─ templates/
│     └─ .ccenv.example
├─ install.sh
├─ uninstall.sh
└─ README.md
```

> **Tip** : install the toolkit _once_ per application‑repo; each Git branch then gets its own container + work‑tree automatically.

---

## 2 · Prerequisites

* **macOS** (tested on Ventura & Sonoma)
* **Homebrew** packages
  ```bash
  brew install colima docker aws-vault
  colima start --cpu 4 --memory 8
  ```
* A valid **AWS SSO profile** in `~/.aws/config` (e.g. `[profile dev‑sso]`).

---

## 3 · Configuration file

`scripts/templates/.ccenv.example` – copy to `<repo>/.cc/.ccenv` to override defaults.

```dotenv
# Claude / Bedrock
CLAUDE_CODE_USE_BEDROCK=1
ANTHROPIC_MODEL=us.anthropic.claude-3-sonnet-20250219-v1:0

# Work‑tree parking lot
WT_ROOT=$HOME/worktrees

# IMDS endpoint from aws‑vault --server
IMDS_URL=http://host.docker.internal:9099/12345

# Docker resource hints – uncomment to set
# CPU_LIMIT=4
# MEM_LIMIT=8g
```

---

## 4 · Script details

Below are full Bash sources.  
_All scripts rely on `#!/usr/bin/env bash`, `set -euo pipefail`, and `_common.sh` helpers._

### 4.1  `scripts/_common.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

# -------- util helpers ----------
_red()  { printf "\\e[31m%s\\e[0m\\n" "$*"; }
_green(){ printf "\\e[32m%s\\e[0m\\n" "$*"; }
_die()  { _red "✖ $*"; exit 1; }

_need() {
  command -v "$1" >/dev/null 2>&1 || _die "Missing dependency: $1"
}

# -------- load config -----------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_REPO="$(git -C "$SCRIPT_DIR/../.." rev-parse --show-toplevel 2>/dev/null || true)"

# repo‑local env overrides
[[ -f "$ROOT_REPO/.cc/.ccenv" ]] && source "$ROOT_REPO/.cc/.ccenv"
# user‑global overrides
[[ -f "$HOME/.ccenv" ]] && source "$HOME/.ccenv"

# defaults
WT_ROOT="${{WT_ROOT:-$HOME/worktrees}}"
CLAUDE_CODE_USE_BEDROCK="${{CLAUDE_CODE_USE_BEDROCK:-1}}"
ANTHROPIC_MODEL="${{ANTHROPIC_MODEL:-us.anthropic.claude-3-sonnet-20250219-v1:0}}"
CPU_LIMIT="${{CPU_LIMIT:-}}"
MEM_LIMIT="${{MEM_LIMIT:-}}"
```

### 4.2  `scripts/cc-awsvault`

```bash
#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_common.sh"

_need aws-vault
PORT="${{PORT:-9099}}"

PROFILE="${{1:-${{AWS_PROFILE:-}}}}"
[[ -z "$PROFILE" ]] && _die "Usage: cc-awsvault <aws-profile> (or set AWS_PROFILE)"

# already running?
if lsof -i :"$PORT" | grep -q aws-vault; then
  _green "aws-vault credential server already running on port $PORT"
  exit 0
fi

_green "Starting aws-vault --server with profile $PROFILE ..."
aws-vault exec "$PROFILE" --server --listen 127.0.0.1:"$PORT" &
sleep 2

URL="http://host.docker.internal:${{PORT}}/"
_green "IMDS endpoint: $URL"
echo "export IMDS_URL=$URL"
```

### 4.3  `scripts/cc-up`

```bash
#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_common.sh"
_need docker
_need git

REPO_NAME="$(basename "$(git rev-parse --show-toplevel)")"
BRANCH="$(git symbolic-ref --quiet --short HEAD)"
[[ -z "$BRANCH" ]] && _die "Not on a branch; git worktree requires a branch"
WORKTREE_DIR="$WT_ROOT/$REPO_NAME/$BRANCH"
CTR="cc-${{BRANCH//\//-}}"

# ensure worktree exists
if [[ ! -d "$WORKTREE_DIR" ]]; then
  git worktree add "$WORKTREE_DIR" "$BRANCH"
fi

# compose env file
ENV_FILE="$WORKTREE_DIR/.env.compose"
IMDS_URL="${{IMDS_URL:?IMDS_URL missing. Run cc-awsvault <profile> first.}}"

cat >"$ENV_FILE" <<EOF
WORKTREE=$WORKTREE_DIR
IMDS_URL=$IMDS_URL
CC_CONTAINER_NAME=$CTR
CLAUDE_CODE_USE_BEDROCK=$CLAUDE_CODE_USE_BEDROCK
ANTHROPIC_MODEL=$ANTHROPIC_MODEL
CC_BRANCH=$BRANCH
CPU_LIMIT=$CPU_LIMIT
MEM_LIMIT=$MEM_LIMIT
EOF

docker compose --env-file "$ENV_FILE" up -d dev

echo "$CTR" > "$WORKTREE_DIR/.cc-container"
_green "✔ Container $CTR running for $BRANCH at $WORKTREE_DIR"
```

### 4.4  `scripts/cc-chat`

```bash
#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_common.sh"

CTR_FILE="$(pwd)/.cc-container"
[[ ! -f "$CTR_FILE" ]] && _die "Run cc-up first."
CTR="$(cat "$CTR_FILE")"

docker exec -it "$CTR" bash -c "cd /workspace && claude"
```

### 4.5  `scripts/cc-stop`

```bash
#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_common.sh"

ENV_FILE="$(pwd)/.env.compose"
[[ ! -f "$ENV_FILE" ]] && _die ".env.compose not found – are you in a worktree?"
docker compose --env-file "$ENV_FILE" down
_green "Container stopped"
```

### 4.6  `scripts/cc-clean`

```bash
#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_common.sh"

WT_DIR="$(pwd)"
ENV_FILE="$WT_DIR/.env.compose"

[[ -f "$ENV_FILE" ]] && docker compose --env-file "$ENV_FILE" down || true

git worktree remove --force "$WT_DIR"
git -C "$(git rev-parse --show-toplevel)" worktree prune

cd ..
rm -rf "$WT_DIR"
_green "✔ Worktree & container cleaned"
```

---

## 5 · Docker artefacts

### 5.1  `Dockerfile`

```Dockerfile
FROM alpine:latest

RUN apk add --no-cache bash curl git nodejs npm python3 py3-pip tini

RUN npm install -g @anthropic-ai/claude-code

ENV CLAUDE_CODE_USE_BEDROCK=1 \
    ANTHROPIC_MODEL=us.anthropic.claude-3-sonnet-20250219-v1:0

ENTRYPOINT ["/sbin/tini","--"]
CMD ["bash"]
```

### 5.2  `docker-compose.yml`

```yaml
version: "3.9"

services:
  dev:
    build: .
    container_name: ${CC_CONTAINER_NAME}
    working_dir: /workspace
    volumes:
      - ${WORKTREE}:/workspace
    environment:
      - AWS_CONTAINER_CREDENTIALS_FULL_URI=${IMDS_URL}
      - CLAUDE_CODE_USE_BEDROCK=${CLAUDE_CODE_USE_BEDROCK}
      - ANTHROPIC_MODEL=${ANTHROPIC_MODEL}
    deploy:
      resources:
        limits:
          cpus: ${CPU_LIMIT:-}
          memory: ${MEM_LIMIT:-}
```

---

## 6 · Installer & uninstaller

### 6.1 `install.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

TARGET=${1:?Usage: install.sh /path/to/repo}
[[ ! -d "$TARGET/.git" ]] && { echo "✖ $TARGET is not a Git repo"; exit 1; }

mkdir -p "$TARGET/.cc/scripts"
cp -R scripts/* "$TARGET/.cc/scripts/"
cp scripts/templates/.ccenv.example "$TARGET/.cc/.ccenv.example"

echo 'export PATH="$PATH:$(git rev-parse --show-toplevel)/.cc/scripts"' >> "$TARGET/.envrc" || true

echo "✔ Claude dev scripts installed in $TARGET"
```

### 6.2 `uninstall.sh`

```bash
#!/usr/bin/env bash
set -euo pipefail

TARGET=${1:?Usage: uninstall.sh /path/to/repo}
[[ ! -d "$TARGET/.git" ]] && { echo "✖ $TARGET is not a Git repo"; exit 1; }

find "$TARGET" -name .env.compose -print0 | while IFS= read -r -d '' ENVF; do
  docker compose --env-file "$ENVF" down || true
done

rm -rf "$TARGET/.cc"
sed -i '' '/.cc\/scripts/d' "$TARGET/.envrc" 2>/dev/null || true

echo "✔ Uninstalled Claude dev tooling from $TARGET"
```

---

## 7 · Usage flow

```bash
# Clone sandbox & install into your project
git clone https://github.com/you/claude-dev-sandbox.git
./claude-dev-sandbox/install.sh ~/dev/my-app

# Start credential server (once)
cc-awsvault dev-sso

# Create or switch to a branch
git checkout -b feature/login

# Spin up container + work-tree
cc-up

# Open chat
cc-chat

# Clean up when done
cc-clean
```

---

## 8 · Extending the system

* **Add packages** – edit `Dockerfile`, rebuild.
* **Database sidecar** – extend `docker-compose.yml`.
* **Resource limits** – set `CPU_LIMIT` / `MEM_LIMIT` in `.ccenv`.
* **Rootless future** – add `RUN adduser -D dev && USER dev` to Dockerfile.

---

## 9 · Change‑log

Create `CHANGELOG.md`, update on each release.

---

*End of guide.*
