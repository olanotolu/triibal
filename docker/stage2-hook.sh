#!/bin/sh
# s6-overlay stage2 hook — runs as root after the supervision tree is
# up but before user services start. Handles UID/GID remap, volume
# chown, config seeding, and skills sync.
#
# Per-service privilege drop happens inside each service's `run` script
# (and in main-wrapper.sh) via s6-setuidgid, not here.
#
# Wired into the image as /etc/cont-init.d/01-triibal-setup by the
# Dockerfile. The shim at docker/entrypoint.sh forwards to this script
# so external references to docker/entrypoint.sh still work.
#
# NB: cont-init.d scripts run with no arguments — the user's CMD args
# are NOT visible here. That's fine: we use Architecture B (s6-overlay
# main-program model), so main-wrapper.sh runs the CMD with full
# stdin/stdout/stderr access and handles arg parsing there.

set -eu

TRIIBAL_HOME="${TRIIBAL_HOME:-/opt/data}"
INSTALL_DIR="/opt/triibal"

# --- Bootstrap TRIIBAL_HOME as root ---
# Create the directory (and any missing parents) while we still have root
# privileges so the chown checks below see real metadata and the later
# `s6-setuidgid triibal mkdir -p` block doesn't EACCES on root-owned
# ancestors. Without this, custom TRIIBAL_HOME paths whose parents only
# root can create (e.g. `TRIIBAL_HOME=/home/triibal/.triibal` in a Compose
# file, or any path under a fresh / not pre-populated by the image)
# fail on first boot with `mkdir: cannot create directory '/...': Permission
# denied` and the cont-init hook exits non-zero. Idempotent — `mkdir -p`
# is a no-op if the dir already exists. (#18482, salvages #18488)
mkdir -p "$TRIIBAL_HOME"

# --- UID/GID remap ---
if [ -n "${TRIIBAL_UID:-}" ] && [ "$TRIIBAL_UID" != "$(id -u triibal)" ]; then
    echo "[stage2] Changing triibal UID to $TRIIBAL_UID"
    usermod -u "$TRIIBAL_UID" triibal
fi
if [ -n "${TRIIBAL_GID:-}" ] && [ "$TRIIBAL_GID" != "$(id -g triibal)" ]; then
    echo "[stage2] Changing triibal GID to $TRIIBAL_GID"
    # -o allows non-unique GID (e.g. macOS GID 20 "staff" may already
    # exist as "dialout" in the Debian-based container image).
    groupmod -o -g "$TRIIBAL_GID" triibal 2>/dev/null || true
fi

# --- Fix ownership of data volume ---
# When TRIIBAL_UID is remapped or the top-level $TRIIBAL_HOME isn't owned by
# the runtime triibal UID, restore ownership to triibal — but ONLY for the
# directories triibal actually writes to. The full $TRIIBAL_HOME may be a
# host-mounted bind containing unrelated user files; `chown -R` would
# silently destroy host ownership of those (see issue #19788).
#
# The canonical list of triibal-owned subdirs is the same one the s6-setuidgid
# mkdir -p block below seeds. Keep them in sync if the seed list changes.
actual_triibal_uid=$(id -u triibal)
needs_chown=false
if [ -n "${TRIIBAL_UID:-}" ] && [ "$TRIIBAL_UID" != "10000" ]; then
    needs_chown=true
elif [ "$(stat -c %u "$TRIIBAL_HOME" 2>/dev/null)" != "$actual_triibal_uid" ]; then
    needs_chown=true
fi
if [ "$needs_chown" = true ]; then
    echo "[stage2] Fixing ownership of $TRIIBAL_HOME (targeted) to triibal ($actual_triibal_uid)"
    # In rootless Podman the container's "root" is mapped to an
    # unprivileged host UID — chown will fail. That's fine: the volume
    # is already owned by the mapped user on the host side.
    #
    # Top-level $TRIIBAL_HOME: chown the directory itself (not its contents)
    # so triibal can mkdir new subdirs but bind-mounted host files keep
    # their existing ownership.
    chown triibal:triibal "$TRIIBAL_HOME" 2>/dev/null || \
        echo "[stage2] Warning: chown $TRIIBAL_HOME failed (rootless container?) — continuing"
    # Triibal-owned subdirs: recursive chown is safe here because these are
    # created and managed exclusively by triibal (see the s6-setuidgid mkdir
    # -p block below for the canonical list).
    for sub in cron sessions logs hooks memories skills skins plans workspace home profiles; do
        if [ -e "$TRIIBAL_HOME/$sub" ]; then
            chown -R triibal:triibal "$TRIIBAL_HOME/$sub" 2>/dev/null || \
                echo "[stage2] Warning: chown $TRIIBAL_HOME/$sub failed (rootless container?) — continuing"
        fi
    done
    # Triibal-owned trees under $INSTALL_DIR must be re-chowned when the UID
    # is remapped — otherwise:
    #   - .venv: lazy_deps.py cannot install platform packages (discord.py,
    #     telegram, slack, etc.) with EACCES (#15012, #21100)
    #   - ui-tui: esbuild rebuilds dist/entry.js on every TUI launch (when
    #     the source mtime is newer than dist/ or when TRIIBAL_TUI_FORCE_BUILD
    #     is set) and writes to ui-tui/dist/. Without this chown the new
    #     triibal UID can't write the build output (#28851).
    #   - node_modules: root-level dependencies (puppeteer, web tooling)
    #     that runtime code may walk/update.
    # The set mirrors the build-time `chown -R triibal:triibal` line in the
    # Dockerfile — keep them in sync if the Dockerfile chown set changes.
    # These are under $INSTALL_DIR (not $TRIIBAL_HOME), so the bind-mount
    # concern doesn't apply — recursive is fine.
    chown -R triibal:triibal \
        "$INSTALL_DIR/.venv" \
        "$INSTALL_DIR/ui-tui" \
        "$INSTALL_DIR/node_modules" \
        2>/dev/null || \
        echo "[stage2] Warning: chown of build trees failed (rootless container?) — continuing"
fi

# Always reset ownership of $TRIIBAL_HOME/profiles to triibal on every
# boot. Profile dirs and files can land owned by root when commands
# are invoked via `docker exec <container> triibal …` (which defaults
# to root unless `-u` is passed), and that breaks the cont-init
# reconciler (02-reconcile-profiles) which runs as triibal and walks
# the profiles dir. Idempotent; skipped on rootless containers where
# chown would fail.
if [ -d "$TRIIBAL_HOME/profiles" ]; then
    chown -R triibal:triibal "$TRIIBAL_HOME/profiles" 2>/dev/null || true
fi

# --- config.yaml permissions ---
# Ensure config.yaml is readable by the triibal runtime user even if it
# was edited on the host after initial ownership setup.
if [ -f "$TRIIBAL_HOME/config.yaml" ]; then
    chown triibal:triibal "$TRIIBAL_HOME/config.yaml" 2>/dev/null || true
    chmod 640 "$TRIIBAL_HOME/config.yaml" 2>/dev/null || true
fi

# --- Seed directory structure as triibal user ---
# Run as triibal via s6-setuidgid so dirs end up owned correctly (matters
# under rootless Podman where chown back to root would fail).
#
# Use direct `mkdir -p` invocation (no `sh -c "..."` wrapper) so the
# shell isn't a second interpreter — defends against $TRIIBAL_HOME values
# containing shell metacharacters. PR #30136 review item O2.
s6-setuidgid triibal mkdir -p \
    "$TRIIBAL_HOME/cron" \
    "$TRIIBAL_HOME/sessions" \
    "$TRIIBAL_HOME/logs" \
    "$TRIIBAL_HOME/hooks" \
    "$TRIIBAL_HOME/memories" \
    "$TRIIBAL_HOME/skills" \
    "$TRIIBAL_HOME/skins" \
    "$TRIIBAL_HOME/plans" \
    "$TRIIBAL_HOME/workspace" \
    "$TRIIBAL_HOME/home"

# --- Install-method stamp (read by detect_install_method() in triibal status) ---
# Preserved from the tini-era entrypoint (PR #27843). Must be written as
# the triibal user so ownership matches the file's documented owner.
# tee is invoked directly via s6-setuidgid (no `sh -c` wrapper) for the
# same shell-metacharacter safety described above.
printf 'docker\n' | s6-setuidgid triibal tee "$TRIIBAL_HOME/.install_method" >/dev/null \
    || true

# --- Seed config files (only on first boot) ---
seed_one() {
    dest=$1
    src=$2
    if [ ! -f "$TRIIBAL_HOME/$dest" ] && [ -f "$INSTALL_DIR/$src" ]; then
        s6-setuidgid triibal cp "$INSTALL_DIR/$src" "$TRIIBAL_HOME/$dest"
    fi
}
seed_one ".env" ".env.example"
seed_one "config.yaml" "cli-config.yaml.example"
seed_one "SOUL.md" "docker/SOUL.md"

# .env holds API keys and secrets — restrict to owner-only access. Applied
# unconditionally (not only on first-seed) so a host-mounted .env that was
# created with a permissive umask gets tightened on every container start.
if [ -f "$TRIIBAL_HOME/.env" ]; then
    chown triibal:triibal "$TRIIBAL_HOME/.env" 2>/dev/null || true
    chmod 600 "$TRIIBAL_HOME/.env" 2>/dev/null || true
fi

# auth.json: bootstrap from env on first boot only. Same semantics as the
# pre-s6 entrypoint — the [ ! -f ] guard is critical to avoid clobbering
# rotated refresh tokens on container restart.
if [ ! -f "$TRIIBAL_HOME/auth.json" ] && [ -n "${TRIIBAL_AUTH_JSON_BOOTSTRAP:-}" ]; then
    printf '%s' "$TRIIBAL_AUTH_JSON_BOOTSTRAP" > "$TRIIBAL_HOME/auth.json"
    chown triibal:triibal "$TRIIBAL_HOME/auth.json" 2>/dev/null || true
    chmod 600 "$TRIIBAL_HOME/auth.json"
fi

# --- Sync bundled skills ---
# Invoke the venv's python by absolute path so we don't need a `sh -c`
# wrapper to source the activate script. This is safe because
# skills_sync.py doesn't depend on any environment exports beyond what
# the python binary's own bin-stub already sets up (sys.path is rooted
# at the venv's site-packages by virtue of running .venv/bin/python).
if [ -d "$INSTALL_DIR/skills" ]; then
    s6-setuidgid triibal "$INSTALL_DIR/.venv/bin/python" "$INSTALL_DIR/tools/skills_sync.py" \
        || echo "[stage2] Warning: skills_sync.py failed; continuing"
fi

# --- Discover agent-browser's Chromium binary ---
# The image's Dockerfile runs `npx playwright install chromium`, which
# populates ``$PLAYWRIGHT_BROWSERS_PATH`` (=/opt/triibal/.playwright) with
# a ``chromium_headless_shell-<build>/chrome-headless-shell-linux64/``
# directory. agent-browser (the runtime CLI Triibal spawns for the
# browser tool) doesn't recognise this layout in its own cache scan and
# fails with "Auto-launch failed: Chrome not found" — even though the
# binary is right there (#15697).
#
# Fix: locate the binary at boot and export ``AGENT_BROWSER_EXECUTABLE_PATH``
# via /run/s6/container_environment so the `with-contenv` shebang on
# main-wrapper.sh propagates it into the supervised ``triibal`` process
# and thence to agent-browser subprocesses.
#
# - Skipped when the user has already set ``AGENT_BROWSER_EXECUTABLE_PATH``
#   (lets users override with a system Chrome install).
# - Filename-matched (not path-matched): the chromium dir contains many
#   shared libraries (libGLESv2.so, libEGL.so, ...) which inherit the
#   executable bit from Playwright's tarball but are NOT browser binaries.
#   We only accept files whose basename is chrome / chromium /
#   chrome-headless-shell / chromium-browser. Compare PR #18635's earlier
#   ``find | grep -Ei 'chrome|chromium'`` which would match the path
#   ``.../chrome-headless-shell-linux64/libGLESv2.so`` and pick a .so.
# - Quietly skipped when $PLAYWRIGHT_BROWSERS_PATH doesn't exist (e.g.
#   custom builds that strip Playwright).
if [ -z "${AGENT_BROWSER_EXECUTABLE_PATH:-}" ] && \
        [ -n "${PLAYWRIGHT_BROWSERS_PATH:-}" ] && \
        [ -d "$PLAYWRIGHT_BROWSERS_PATH" ]; then
    browser_bin=$(find "$PLAYWRIGHT_BROWSERS_PATH" -type f -executable \
        \( -name 'chrome' -o -name 'chromium' \
           -o -name 'chrome-headless-shell' -o -name 'chromium-browser' \) \
        2>/dev/null | head -n 1)
    if [ -n "$browser_bin" ]; then
        echo "[stage2] Found agent-browser Chromium binary: $browser_bin"
        # Write to s6's container_environment so with-contenv picks it
        # up for all supervised services (main-triibal, dashboard, etc.).
        # Idempotent: each boot overwrites with the current path.
        printf '%s' "$browser_bin" > /run/s6/container_environment/AGENT_BROWSER_EXECUTABLE_PATH
    else
        echo "[stage2] Warning: no Chromium binary under $PLAYWRIGHT_BROWSERS_PATH; browser tool may fail"
    fi
fi

echo "[stage2] Setup complete; starting user services"
